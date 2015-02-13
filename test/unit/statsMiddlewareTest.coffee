fs = require "fs"
should = require "should"
sinon = require "sinon"
http = require "http"
stats = require "../../lib/middleware/stats"
testUtils = require "../testUtils"
FakeServer = require "../fakeTcpServer"
timer = new Date()
config = require '../../lib/config/config'
application = config.get 'application'
os = require "os"
domain = os.hostname() + '.' + application.name



describe "Stats Middleware ", ->
  this.timeout 20000
  s = {}

  beforeEach (done) ->
    s = new FakeServer()
    s.start done

  afterEach ->
    s.stop()


  channel =
    _id: "ckjhfjwedsnfdsf"
    name: "Mock endpoint"
    urlPattern: ".+"
    routes: [
      secured: true
      host: 'localhost'
      port: 9877
      primary: true
      cert: fs.readFileSync 'test/resources/server-tls/cert.pem'
    ]

  requestTimestamp = (new Date()).toString()
  ctx = new Object()
  ctx.authorisedChannel = channel
  ctx.request = new Object()
  ctx.response = new Object()
  ctx.response.set = ->
  ctx.path = ctx.request.url = "/test"
  ctx.request.method = "GET"
  ctx.requestTimestamp = requestTimestamp
  ctx.transactionStatus = "Successful"
  ctx.routes = []
  ctx.mediatorResponse = new Object()
  ctx.mediatorResponse.properties =
    name: 'primary mediator'
  ctx.mediatorResponse.metrics = []
  ctx.mediatorResponse.orchestrations = [
    name: "Lab API"
    request:
      path: "api/patient/lab"
      headers:
        "Content-Type": "text/plain"
      body: "<route request>"
      method: "POST"
      timestamp: 1412257881904
    response:
      status: "200"
      headers: {}
      body: "<route response>"
      timestamp: 1412257881909
    metrics : []
  ]


#Non Primary routes
  ctx.routes.push
    name: "secondary route"
    request:
      path: "api/patient/lab"
      headers:
        "Content-Type": "text/plain"
      body: "<route request>"
      method: "POST"
      timestamp: 1412257881904
    "response":
      "status": 200
      "headers":
        "content-type": "application\/json"
      "body": "Primary Route Reached"
      "timestamp": 1423489768398

    orchestrations: [
      name: "Lab API"
      request:
        path: "api/patient/lab"
        headers:
          "Content-Type": "text/plain"
        body: "<route request>"
        method: "POST"
        timestamp: 1412257881904
      response:
        status: "200"
        headers: {}
        body: "<route response>"
        timestamp: 1412257881909
    ]

#    Adding Custom Metrics
  ctx.mediatorResponse.metrics.push
      name: 'my-counter-metric'
      type: 'counter'
      value: 1
  ctx.mediatorResponse.metrics.push
    name: 'my-gauge-metric'
    type: 'gauge'
    value: 11
  ctx.mediatorResponse.metrics.push
    name: 'my-timer-metric'
    type: 'timer'
    value: 1522





  it "should increment the transaction counter", (done) ->
    this.timeout = 400000
    stats.incrementTransactionCount ctx, () ->
      s.expectMessage domain + '.channels:1|c', ->
        s.expectMessage domain + '.channels.Successful:1|c', ->
          s.expectMessage domain + '.channels.ckjhfjwedsnfdsf:1|c', ->
            s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.orchestrations.Lab API:1|c', ->
              s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.orchestrations.Lab API.statusCodes.200:1|c', ->
                s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.statuses.Successful.orchestrations.Lab API:1|c', ->
                  s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.statuses.Successful.orchestrations.Lab API.statusCodes.200:1|c', ->
                    s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.primary mediator.mediator_metrics.my-counter-metric:1|c', ->
                      s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.primary mediator.mediator_metrics.my-gauge-metric:11|g', ->
                        s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.primary mediator.mediator_metrics.my-timer-metric:1522|ms', done

  it "Should measure transaction duration", (done) ->
      ctx.timer = 10
      stats.measureTransactionDuration ctx, () ->
        s.expectMessage domain + '.channels:10|ms', ->
          s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.orchestrations.Lab API:5|ms', ->
            s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.orchestrations.Lab API.statusCodes.200:5|ms', ->
              s.expectMessage domain + '.channels.Successful:10|ms', ->
                s.expectMessage domain + '.channels.ckjhfjwedsnfdsf:10|ms', ->
                  s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.statuses.Successful:10|ms', ->
                    s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.nonPrimaryRoutes.secondary route:10|ms', ->
                      s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.nonPrimaryRoutes.secondary route.statusCodes.200:10|ms', ->
                        s.expectMessage domain + '.channels.ckjhfjwedsnfdsf.nonPrimaryRoutes.secondary route.orchestrations.Lab API:5|ms', done





