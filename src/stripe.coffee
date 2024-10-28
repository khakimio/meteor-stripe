import {Meteor} from 'meteor/meteor'
import {WebApp} from 'meteor/webapp'
import {fetch} from 'meteor/fetch'
import Stripe from 'stripe'

class Stripe
  constructor: ->
    config = @config()
    @stripe = new Stripe(config.secretKey)
    @_setupWebhookHandler()

  config: (cfg) ->
    @_config ?= Meteor.settings.stripe
    return @_config unless cfg
    Object.assign(@_config, cfg)
    
  createOrder: (params) ->
    await @stripe.orders.create(params)

  retrieveOrder: (id) ->
    await @stripe.orders.retrieve(id)

  updateOrder: (id, params) ->
    await @stripe.orders.update(id, params)

  cancelOrder: (id) ->
    await @stripe.orders.cancel(id)

  listOrders: (params) ->
    await @stripe.orders.list(params)

  createPaymentIntent: (params) ->
    await @stripe.paymentIntents.create(params)

  retrievePaymentIntent: (id) ->
    await @stripe.paymentIntents.retrieve(id)

  updatePaymentIntent: (id, params) ->
    await @stripe.paymentIntents.update(id, params)

  cancelPaymentIntent: (id) ->
    await @stripe.paymentIntents.cancel(id)

  createRefund: (params) ->
    await @stripe.refunds.create(params)

  createCustomer: (params) ->
    await @stripe.customers.create(params)

  payWithCard: (params) ->
    await @stripe.paymentMethods.create({
      type: 'card'
      card: params.card
    }).then (paymentMethod) =>
      await @stripe.paymentIntents.create({
        amount: params.amount
        currency: params.currency or @config().currency
        payment_method: paymentMethod.id
        confirm: true
        customer: params.customerId
        setup_future_usage: params.setupFutureUsage
        metadata: {
          order_id: params.orderId # Добавляем order_id в metadata
        }
      })

  onPaymentSucceeded: (cb) -> @_onPaymentSucceeded = cb
  onPaymentFailed: (cb) -> @_onPaymentFailed = cb
  onRefundSucceeded: (cb) -> @_onRefundSucceeded = cb

  _setupWebhookHandler: ->
    config = @config()
    WebApp.connectHandlers.use "/api/#{config.webhookPath}", @_webhookHandler

  _webhookHandler: (req, res, next) =>
    return res.writeHead(405) if req.method isnt 'POST'

    body = await new Promise (resolve, reject) ->
      chunks = []
      req.on 'data', (chunk) -> chunks.push(chunk)
      req.on 'end', -> resolve Buffer.concat(chunks).toString('utf-8')
      req.on 'error', reject

    signature = req.headers['stripe-signature']
    config = @config()

    try
      event = @stripe.webhooks.constructEvent(
        body,
        signature,
        config.webhookSecret
      )

      switch event.type
        when 'payment_intent.succeeded'
          await @_onPaymentSucceeded?(event.data.object)
        when 'payment_intent.payment_failed'
          await @_onPaymentFailed?(event.data.object)
        when 'charge.refunded'
          await @_onRefundSucceeded?(event.data.object)

      res.writeHead(200)
      res.end(JSON.stringify(received: true))

    catch err
      console.error('Stripe webhook error:', err.message)
      res.writeHead(400)
      res.end(JSON.stringify(error: err.message))

export default Stripe = new Stripe
