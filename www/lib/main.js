(function() {
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  (function() {
    var Factory, Hitbox, Position, Velocity, World, assert, bound, onload, seek, seekVelocity;
    assert = function(val, msg) {
      if (!val) {
        throw new Error(msg);
      }
    };
    Position = (function() {
      function Position(self, x, y) {
        this.self = self;
        this.x = x;
        this.y = y;
      }
      Position.prototype.distance = function(that) {
        var dx, dy;
        dx = this.x - that.x;
        dy = this.y - that.y;
        return Math.pow(dx * dx + dy * dy, 0.5);
      };
      Position.prototype.trig = function(that) {
        var adj, hyp, opp;
        adj = this.x - that.x;
        opp = this.y - that.y;
        hyp = this.distance(that);
        return {
          sin: opp / hyp,
          cos: adj / hyp,
          tan: opp / adj
        };
      };
      Position.prototype.addXY = function(dx, dy) {
        assert(dx != null);
        assert(dy != null);
        this.x += dx;
        return this.y += dy;
      };
      return Position;
    })();
    bound = function(val, min, max) {
      return Math.min(max, Math.max(min, val));
    };
    Velocity = (function() {
      function Velocity() {
        Velocity.__super__.constructor.apply(this, arguments);
      }
      __extends(Velocity, Position);
      return Velocity;
    })();
    Hitbox = (function() {
      function Hitbox(self, radius) {
        this.self = self;
        this.radius = radius;
      }
      Hitbox.prototype.isCollision = function(that) {
        var allowed, distance;
        distance = this.self.position.distance(that.self.position);
        allowed = this.radius + that.radius;
        return allowed >= distance;
      };
      return Hitbox;
    })();
    seek = function(position, speed, target) {
      var distance, trig;
      distance = position.distance(target);
      if (distance <= speed) {
        position.x = target.x;
        return position.y = target.y;
      } else {
        trig = position.trig(target);
        return position.addXY(-trig.cos * speed, -trig.sin * speed);
      }
    };
    seekVelocity = function(velocity, position, speed, target, max) {
      var trig;
      if (max == null) {
        max = 10;
      }
      trig = position.trig(target);
      velocity.addXY(-trig.cos * speed, -trig.sin * speed);
      velocity.x = bound(velocity.x, -max, max);
      return velocity.y = bound(velocity.y, -max, max);
    };
    Factory = (function() {
      function Factory(svg) {
        this.svg = svg;
      }
      Factory.prototype.player = function() {
        var ret;
        ret = {};
        ret.position = new Position(ret, 320, 320);
        ret.hitbox = new Hitbox(ret, 10);
        ret.sprite = this.svg.circle(ret.position.x, ret.position.y, ret.hitbox.radius, {
          fill: 'blue'
        });
        return ret;
      };
      Factory.prototype.boss = function() {
        var ret;
        ret = {};
        ret.position = new Position(ret, 320, 80);
        ret.hitbox = new Hitbox(ret, 20);
        ret.sprite = this.svg.circle(ret.position.x, ret.position.y, ret.hitbox.radius, {
          fill: 'red'
        });
        return ret;
      };
      Factory.prototype.doll = function(boss) {
        var ret;
        ret = {};
        ret.position = new Position(ret, boss.position.x, boss.position.y);
        ret.velocity = new Velocity(ret, 5 - 10 * Math.random(), 5 - 10 * Math.random());
        ret.hitbox = new Hitbox(ret, 5);
        ret.sprite = this.svg.circle(ret.position.x, ret.position.y, ret.hitbox.radius, {
          fill: 'red'
        });
        return ret;
      };
      return Factory;
    })();
    World = (function() {
      function World(svg) {
        this.factory = new Factory(svg);
        this.player = this.factory.player();
        this.boss = this.factory.boss();
        this.dolls = [];
        this.t = 0;
        this.invincibleUntil = 240;
        this.mouse = {
          x: this.player.position.x,
          y: this.player.position.y
        };
        $('#content').mousemove(__bind(function(e) {
          var offset, rad;
          offset = $('#content').offset();
          rad = this.player.hitbox.radius;
          this.mouse.x = bound(e.pageX - offset.left, rad, 640 - rad);
          return this.mouse.y = bound(e.pageY - offset.top, rad, 480 - rad);
        }, this));
        this.shoot = false;
        $('#content').mousedown(__bind(function(e) {
          return this.shoot = !this.invincible();
        }, this));
        $('#content').mouseup(__bind(function(e) {
          return this.shoot = false;
        }, this));
      }
      World.prototype.invincible = function() {
        return this.t <= this.invincibleUntil;
      };
      World.prototype.tick = function() {
        var collides, doll, i, _i, _len, _ref, _ref2, _ref3;
        seek(this.player.position, 3, this.mouse);
        this.player.sprite.setAttribute('cx', this.player.position.x);
        this.player.sprite.setAttribute('cy', this.player.position.y);
        collides = _.detect(this.dolls, __bind(function(d) {
          return d.hitbox.isCollision(this.player.hitbox);
        }, this));
        if (collides && !this.invincible()) {
          this.player.position.x = 320;
          this.player.position.y = 320;
          this.invincibleUntil = this.t + 240;
        }
        this.boss.position.x = 320 + 240 * Math.cos(this.t * Math.PI / 240);
        this.boss.sprite.setAttribute('cx', this.boss.position.x);
        if (this.t % (60 * 5) === 0) {
          this.dolls.push(this.factory.doll(this.boss));
          $('#count').text(this.dolls.length);
          if (this.t === 0) {
            for (i = 0; i < 3; i++) {
              this.dolls.push(this.factory.doll(this.boss));
            }
          }
        }
        _ref = this.dolls;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          doll = _ref[_i];
          if (this.shoot) {
            seekVelocity(doll.velocity, doll.position, 0.1, this.player.position);
          }
          doll.position.addXY(doll.velocity.x, doll.velocity.y);
          doll.sprite.setAttribute('cx', doll.position.x);
          doll.sprite.setAttribute('cy', doll.position.y);
          if (!((0 < (_ref2 = doll.position.x) && _ref2 < 640))) {
            doll.position.x = doll.position.x < 0 ? 0 : 640;
            doll.velocity.x *= -0.4;
          }
          if (!((0 < (_ref3 = doll.position.y) && _ref3 < 480))) {
            doll.position.y = doll.position.y < 0 ? 0 : 480;
            doll.velocity.y *= -0.4;
          }
        }
        return this.t += 1;
      };
      return World;
    })();
    onload = function(svg) {
      var world;
      world = new World(svg);
      return setInterval((function() {
        return world.tick();
      }), 16);
    };
    return jQuery(function($) {
      var canvas;
      return canvas = $('#content').svg({
        onLoad: onload
      });
    });
  })();
}).call(this);
