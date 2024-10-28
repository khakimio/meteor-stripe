import {PACKAGE_NAME} from './constants'

Meteor.settings.private = {} unless Meteor.settings.private
Meteor.settings.private[PACKAGE_NAME] = {
  siteUrl: process.env.STRIPE_SITE_URL or Meteor.absoluteUrl()
  publishableKey: process.env.STRIPE_PUBLISHABLE_KEY
  secretKey: process.env.STRIPE_SECRET_KEY
  webhookPath: process.env.STRIPE_WEBHOOK_PATH or 'stripe'
  webhookSecret: process.env.STRIPE_WEBHOOK_SECRET
  currency: process.env.STRIPE_CURRENCY or 'USD'
}

export getConfig = -> Meteor.settings.private[PACKAGE_NAME]