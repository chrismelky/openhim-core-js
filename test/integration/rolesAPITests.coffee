should = require "should"
request = require "supertest"
server = require "../../lib/server"
Channel = require("../../lib/model/channels").Channel
Client = require("../../lib/model/clients").Client
testUtils = require "../testUtils"
auth = require("../testUtils").auth


describe "API Integration Tests", ->

  describe 'Roles REST Api testing', ->

    channel1 =
      name: "TestChannel1"
      urlPattern: "test/sample"
      allow: [ "role1", "role2", "client4" ]
      routes: [
            name: "test route"
            host: "localhost"
            port: 9876
            primary: true
          ]

    channel2 =
      name: "TestChannel2"
      urlPattern: "test/sample"
      allow: [ "role2", "role3"  ]
      routes: [
            name: "test route"
            host: "localhost"
            port: 9876
            primary: true
          ]

    client1 =
      clientID: "client1"
      name: "Client 1"
      roles: [
          "role1"
        ]

    client2 =
      clientID: "client2"
      name: "Client 2"
      roles: [
          "role2"
        ]

    client3 =
      clientID: "client3"
      name: "Client 3"
      roles: [
          "role1"
          "role3"
        ]

    client4 =
      clientID: "client4"
      name: "Client 4"
      roles: [
          "other-role"
        ]

    authDetails = {}

    before (done) ->
      auth.setupTestUsers (err) ->
        return done err if err
        server.start apiPort: 8080, ->
          authDetails = auth.getAuthDetails()
          done()

    after (done) ->
      Client.remove {}, ->
        Channel.remove {}, ->
          server.stop ->
            auth.cleanupTestUsers ->
              done()

    beforeEach (done) ->
      Client.remove {}, ->
        (new Client client1).save (err, cl1) ->
          client1._id = cl1._id
          (new Client client2).save (err, cl2) ->
            client2._id = cl2._id
            (new Client client3).save (err, cl3) ->
              client3._id = cl3._id
              (new Client client4).save (err, cl4) ->
                client4._id = cl4._id
                Channel.remove {}, ->
                  (new Channel channel1).save (err, ch1) ->
                    channel1._id = ch1._id
                    (new Channel channel2).save (err, ch2) ->
                      channel2._id = ch2._id
                      done()


    describe '*getRoles()', ->

      it 'should fetch all roles', (done) ->
        request("https://localhost:8080")
          .get("/roles")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(200)
          .end (err, res) ->
            if err
              done err
            else
              res.body.length.should.be.exactly 3
              names = res.body.map (r) -> r.name
              names.should.containEql 'role1'
              names.should.containEql 'role2'
              names.should.containEql 'role3'

              mapChId = (chns) -> (chns.map (ch) -> ch._id)
              for role in res.body
                if role.name is 'role1'
                  mapChId(role.channels).should.containEql "#{channel1._id}"
                if role.name is 'role2'
                  mapChId(role.channels).should.containEql "#{channel1._id}"
                  mapChId(role.channels).should.containEql "#{channel2._id}"
                if role.name is 'role3'
                  mapChId(role.channels).should.containEql "#{channel2._id}"

              done()

      it 'should not misinterpret a client as a role', (done) ->
        request("https://localhost:8080")
          .get("/roles")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(200)
          .end (err, res) ->
            if err
              done err
            else
              res.body.length.should.be.exactly 3
              names = res.body.map (r) -> r.name
              names.should.not.containEql 'client4'
              done()

      it 'should reject a request from a non root user', (done) ->
        request("https://localhost:8080")
          .get("/roles")
          .set("auth-username", testUtils.nonRootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(403)
          .end (err, res) -> done err

      it 'should return an empty array if there are not channels', (done) ->
        Channel.remove {}, ->
          request("https://localhost:8080")
            .get("/roles")
            .set("auth-username", testUtils.rootUser.email)
            .set("auth-ts", authDetails.authTS)
            .set("auth-salt", authDetails.authSalt)
            .set("auth-token", authDetails.authToken)
            .expect(200)
            .end (err, res) ->
              if err
                done err
              else
                res.body.length.should.be.exactly 0
                done()


    describe '*getRole()', ->

      it 'should get a role', (done) ->
        request("https://localhost:8080")
          .get("/roles/role2")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(200)
          .end (err, res) ->
            if err
              done err
            else
              res.body.should.have.property 'name', 'role2'
              res.body.should.have.property 'channels'
              res.body.channels.length.should.be.exactly 2
              mapChId = (chns) -> (chns.map (ch) -> ch._id)
              mapChId(res.body.channels).should.containEql "#{channel1._id}"
              mapChId(res.body.channels).should.containEql "#{channel2._id}"
              done()

      it 'should respond with 404 Not Found if role does not exist', (done) ->
        request("https://localhost:8080")
          .get("/roles/nonexistent")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(404)
          .end (err, res) -> done err

      it 'should reject a request from a non root user', (done) ->
        request("https://localhost:8080")
          .get("/roles/role1")
          .set("auth-username", testUtils.nonRootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(403)
          .end (err, res) -> done err


    describe '*addRole()', ->

      it 'should respond with 400 Bad Request if role already exists', (done) ->
        request("https://localhost:8080")
          .post("/roles")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            name: 'role1'
            channels: [_id: "#{channel2._id}"]
          .expect(400)
          .end (err, res) -> done err

      it 'should add a role', (done) ->
        request("https://localhost:8080")
          .post("/roles")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            name: 'role4'
            channels: [
                _id: "#{channel1._id}"
              ,
                _id: "#{channel2._id}"
            ]
          .expect(201)
          .end (err, res) ->
            return done err if err
            Channel.find 'allow': '$in': ['role4'], (err, channels) ->
              return done err if err
              channels.length.should.be.exactly 2
              mapChId = (chns) -> (chns.map (ch) -> "#{ch._id}")
              mapChId(channels).should.containEql "#{channel1._id}"
              mapChId(channels).should.containEql "#{channel2._id}"
              done()

      it 'should add a role and update channels specified with either _id or name', (done) ->
        request("https://localhost:8080")
          .post("/roles")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            name: 'role4'
            channels: [
                _id: "#{channel1._id}"
              ,
                name: channel2.name
            ]
          .expect(201)
          .end (err, res) ->
            return done err if err
            Channel.find 'allow': '$in': ['role4'], (err, channels) ->
              return done err if err
              channels.length.should.be.exactly 2
              mapChId = (chns) -> (chns.map (ch) -> "#{ch._id}")
              mapChId(channels).should.containEql "#{channel1._id}"
              mapChId(channels).should.containEql "#{channel2._id}"
              done()


      it 'should reject a request from a non root user', (done) ->
        request("https://localhost:8080")
          .post("/roles")
          .set("auth-username", testUtils.nonRootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            name: 'role4'
            channels: [_id: "#{channel1._id}"]
          .expect(403)
          .end (err, res) -> done err


    describe '*updateRole()', ->

      it 'should respond with 400 Not Found if role doesn\'t exist', (done) ->
        request("https://localhost:8080")
          .put("/roles/role4")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            channels: [_id: "#{channel1._id}"]
          .expect(404)
          .end (err, res) -> done err

      it 'should update a role (enable role1 on channel2 and remove from channel1)', (done) ->
        request("https://localhost:8080")
          .put("/roles/role1")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            channels: [_id: "#{channel2._id}"]
          .expect(200)
          .end (err, res) ->
            return done err if err
            Channel.find 'allow': '$in': ['role1'], (err, channels) ->
              return done err if err
              channels.length.should.be.exactly 1
              mapChId = (chns) -> (chns.map (ch) -> "#{ch._id}")
              mapChId(channels).should.containEql "#{channel2._id}"
              done()

      it 'should update a role (enable role1 on both channel1 and channel2)', (done) ->
        request("https://localhost:8080")
          .put("/roles/role1")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            channels: [
                _id: "#{channel1._id}"
              ,
                _id: "#{channel2._id}"
            ]
          .expect(200)
          .end (err, res) ->
            return done err if err
            Channel.find 'allow': '$in': ['role1'], (err, channels) ->
              return done err if err
              channels.length.should.be.exactly 2
              mapChId = (chns) -> (chns.map (ch) -> "#{ch._id}")
              mapChId(channels).should.containEql "#{channel1._id}"
              mapChId(channels).should.containEql "#{channel2._id}"
              done()

      it 'should remove a role that is an update of an empty channel array', (done) ->
        request("https://localhost:8080")
          .put("/roles/role2")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            channels: []
          .expect(200)
          .end (err, res) ->
            return done err if err
            Channel.find 'allow': '$in': ['role2'], (err, channels) ->
              return done err if err
              channels.length.should.be.exactly 0
              done()

      it 'should update a role using channel name', (done) ->
        request("https://localhost:8080")
          .put("/roles/role1")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            channels: [name: channel2.name]
          .expect(200)
          .end (err, res) ->
            return done err if err
            Channel.find 'allow': '$in': ['role1'], (err, channels) ->
              return done err if err
              channels.length.should.be.exactly 1
              mapChId = (chns) -> (chns.map (ch) -> "#{ch._id}")
              mapChId(channels).should.containEql "#{channel2._id}"
              done()

      it 'should reject a request from a non root user', (done) ->
        request("https://localhost:8080")
          .put("/roles/role1")
          .set("auth-username", testUtils.nonRootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            channels: [_id: "#{channel2._id}"]
          .expect(403)
          .end (err, res) -> done err


    describe '*deleteRole()', ->

      it 'should respond with 404 Not Found if role doesn\'t exist', (done) ->
        request("https://localhost:8080")
          .put("/roles/role4")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send
            channels: [_id: "#{channel1._id}"]
          .expect(404)
          .end (err, res) -> done err

      it 'should delete a role', (done) ->
        request("https://localhost:8080")
          .delete("/roles/role2")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(200)
          .end (err, res) ->
            return done err if err
            Channel.find 'allow': '$in': ['role2'], (err, channels) ->
              return done err if err
              channels.length.should.be.exactly 0
              done()

      it 'should reject a request from a non root user', (done) ->
        request("https://localhost:8080")
          .delete("/roles/role2")
          .set("auth-username", testUtils.nonRootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .expect(403)
          .end (err, res) -> done err
