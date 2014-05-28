window.App = Ember.Application.create({
    // support for remembering auth via localStorage. Only works on modern browsers
    authToken: localStorage['authToken'],

    // global alert error for user feedback <String>
    error: null
});

// Mixin to any Route that you want to be able to send authenticated ajax calls from. Calls that fail for auth
// reasons will result in a redirect to the 'login' route automatically
App.Ajax = Ember.Mixin.create({
    ajaxSuccessHandler: function (json) {
        // in my app, error code 201 is reserved for authentication errors that require a login
        if (json.error != null && json.error.code == 201) {
            App.error.set(json.error.message);
            var self = this;
            // delay to let current processing finish.
            setTimeout(function () { self.transitionTo('login'); });
            // let handlers further down the Promise chain know that we've already handled this one.
            return null;
        }
        return json;
    },

    // perform ajax GET call to retrieve json
    GET: function (url, data) {
        var settings = {data: data || {}};
        settings.url = url;
        settings.dataType = "json";
        settings.type = "GET";
        var authToken = App.get('authToken');
        if (authToken != null) settings.data.authToken = authToken;
        return this.ajax(settings);
    },

    // perform ajax POST call to retrieve json
    POST: function (url, data) {
        var settings = {data: data || {}};
        settings.url = url;
        settings.dataType = "json";
        settings.type = "POST";
        var authToken = App.get('authToken');
        if (authToken != null) settings.data.authToken = authToken;
        // post our data as a JSON object in the request body
        settings.data = JSON.stringify(settings.data);
        return this.ajax(settings);
    },

    ajax: function (settings) {
        var self = this;
        return $.ajax(settings).then(function () {
            // preserve 'this' for the success handler
            return self.ajaxSuccessHandler.apply(self, $.makeArray(arguments));
        });
    }
});

App.Router.map(function () {
    this.resource('login');
    // others...
});

App.ApplicationRoute = Ember.Route.extend(App.Ajax, {
    events: {
        logout: function () {
            this.GET('/auth/logout').then(function (json) {
                if (json != null && json.error != null) {
                    App.set('error', json.error.message);
                }
            });
            // even if we error out, we can still clear our own record
            App.set('authToken', null);
            delete localStorage['authToken'];
            this.transitionTo('login');
        },

        dismissError: function () {
            App.set('error', null);
        }
    }
});

App.LoginCreds = Ember.Object.extend({
    username: null,
    password: null,
    remember: false,

    json: function () {
        return {
            username: this.get('username'),
            password: this.get('password'),
            remember: this.get('remember')
        }
    }
});

App.LoginController = Ember.ObjectController.extend({});
App.LoginRoute = Ember.Route.extend(App.Ajax, {
    model: function () {
        // let our login template fill in the properties of a creds object
        return App.LoginCreds.create({});
    },

    events: {
        login: function () {
            var model = this.modelFor('login'); // <App.LoginCreds>
            var self = this;
            self.GET('/auth/login', model.json()).then(
                function (json) {
                    if (json == null) return; // shouldn't happen, but should still NPE protect
                    if (json.error != null) {
                        // useful for any ajax call: set the global error alert with our error message
                        App.set('error', json.error.message);
                    } else {
                        // setting this value will reveal our logout button
                        App.set('authToken', json.authToken);
                        if (model.get('remember')) {
                            localStorage['authToken'] = json.authToken;
                        } else {
                            // make sure a stale value isn't left behind
                            delete localStorage['authToken'];
                        }
                        // clear out any login error that was left over
                        App.set('error', null);
                        self.router.transitionTo(/*<wherever you want after login>*/);
                    }
                });
        }
    }
});
