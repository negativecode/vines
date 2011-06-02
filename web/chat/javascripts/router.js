var Router = Class.create({
  initialize: function() {
    var session = new Session();
    this.login = new LoginPage(this, session);
    this.chat  = new ChatPage(this, session);
    this.pages = {
      "^#\/messages\/[a-zA-z0-9]{4}$": this.chat
    };
  },

  showChat: function() {
    this.chat.draw();
  },

  draw: function() {
    for (var re in this.pages) {
      if (window.location.hash.match(new RegExp(re))) {
        this.pages[re].draw();
        return;
      }
    }
    this.login.draw();
  }
});
$(function() { new Router().draw(); });
