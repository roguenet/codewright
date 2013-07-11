App.FooRoute = Ember.Route.extend(App.Ajax, {
    model: function () {
        // create and return model
    },

    events: {
        // handle events from the model that result in Ajax calls
        updateBar: function () {
            this.GET('/bar/update', {/* parameters */}).then(
                function (json) {
                    if (json == null) {
                        // there was an auth challenge, and we'll get set to login automatically
                        return;
                    }

                    // process result, likely updating the model and/or moving to another route
                };
        }
    }
});
