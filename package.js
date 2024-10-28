Package.describe({
  name: 'meteor-stripe',
  version: '0.0.1',
  summary: 'Meteor Stripe integration',
  git: 'https://github.com/khakimio/meteor-stripe',
  documentation: 'README.md'
});

Package.onUse(function(api) {
  api.versionsFrom('3.0.3');
  api.use('modules');
  api.use('webapp');
  api.use('underscore');
  api.use('ecmascript');
  api.use('coffeescript');

  api.mainModule('src/stripe.coffee', 'server');
});

Npm.depends({
  'stripe': '13.7.0'
});
