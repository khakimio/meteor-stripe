import {Meteor} from 'meteor/meteor'
import {WebApp} from 'meteor/webapp'
import {fetch} from 'meteor/fetch'
import StripeAPI from 'stripe'
import {getConfig} from './config'

class Stripe
  constructor: ->
    config = getConfig()
    @stripe = new StripeAPI(config.secretKey)
    @_setupWebhookHandler()

  config: (cfg) ->
    config = getConfig()
    return config unless cfg
    Object.assign(config, cfg)

  createOrder: (params) ->
    try
      response = await @stripe.checkout.sessions.create
        success_url: params.successRedirectUrl
        cancel_url: params.cancelUrl
        metadata:
          order_id: params.orderId
          phone: params.phone
        mode: 'payment'
        line_items: [
          price_data:
            currency: params.currency
            unit_amount: params.amount
            product_data:
              name: params.description
          quantity: 1
        ]

      return response
      
    catch error
      console.error 'Error creating order:', error
      throw error

  createCheckoutSession: (params) ->
    await @stripe.checkout.sessions.create(params)

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

  onPaymentSucceeded: (cb) -> @_onPaymentSucceeded = cb
  onPaymentFailed: (cb) -> @_onPaymentFailed = cb
  onRefundSucceeded: (cb) -> @_onRefundSucceeded = cb

  _setupWebhookHandler: ->
    config = @config()
    @webhookPath = "/api/#{config.webhookPath}"
    
    WebApp.rawConnectHandlers.use (req, res, next) =>
      isWebhook = req.url == @webhookPath && req.method == 'POST'

      unless isWebhook
        next()
        return
        
      @_handleWebhookData(req, res, next)

  _handleWebhookData: (req, res, next) ->
    rawBody = ''
    req.on 'data', (chunk) -> rawBody += chunk
    req.on 'end', => 
      req.rawBody = rawBody
      try 
        event = @_validateWebhookSignature(req)
        await @_handleStripeEvent(event)
        @_sendResponse(res, 200, received: true)
      catch err
        @_sendResponse(res, 400, error: "An error occurred while processing webhook: #{err.message}")

  _validateWebhookSignature: (req) ->
    config = @config()
    body = req.rawBody?.toString() || ''
    sig = req.headers['stripe-signature']
    webhookSecret = config.webhookSecret

    if !sig || !webhookSecret
      throw new Error('Webhook secret not found.')

    @stripe.webhooks.constructEvent(body, sig, webhookSecret)

  _handleStripeEvent: (event) ->
    console.log('>>>>>> Webhook received:', event.type)
    switch event.type
      when 'checkout.session.completed'
        await @_onPaymentSucceeded?(event.data.object)
      when 'charge.failed'
        await @_onPaymentFailed?(event.data.object)
      when 'charge.refunded'
        await @_onRefundSucceeded?(event.data.object)
      else
        console.log 'Unknown event type:', event.type

  _sendResponse: (res, statusCode, data) ->
    res.writeHead(statusCode)
    res.end(JSON.stringify(data))

export default Stripe = new Stripe
