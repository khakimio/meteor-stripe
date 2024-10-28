// Import Tinytest from the tinytest Meteor package.
import { Tinytest } from "meteor/tinytest";

// Import and rename a variable exported by meteor-stripe.js.
import { name as packageName } from "meteor/meteor-stripe";

// Write your tests here!
// Here is an example.
Tinytest.add('meteor-stripe - example', function (test) {
  test.equal(packageName, "meteor-stripe");
});
