do ->
  assert = (val, msg) ->
    unless val then throw new Error msg

  # 2D coordinates
  class Position
    constructor: (@self, @x, @y) ->
    distance: (that) ->
      dx = @x - that.x
      dy = @y - that.y
      return Math.pow dx*dx + dy*dy, 0.5
    trig: (that) ->
      adj = @x - that.x
      opp = @y - that.y
      hyp = @distance that
      sin: opp / hyp
      cos: adj / hyp
      tan: opp / adj
    addXY: (dx, dy) ->
      assert dx?
      assert dy?
      @x += dx
      @y += dy

  bound = (val, min, max) ->
    return Math.min max, Math.max min, val
  class Velocity extends Position

  class Hitbox
    constructor: (@self, @radius) ->
    isCollision: (that) ->
      distance = @self.position.distance that.self.position
      allowed = @radius + that.radius
      return allowed >= distance

  seek = (position, speed, target) ->
    distance = position.distance target
    if distance <= speed
      position.x = target.x
      position.y = target.y
    else
      trig = position.trig target
      position.addXY -trig.cos * speed, -trig.sin * speed
  seekVelocity = (velocity, position, speed, target, max=10) ->
    trig = position.trig target
    velocity.addXY -trig.cos * speed, -trig.sin * speed
    # This isn't exact because diagonals, but I can't be arsed to fix it
    velocity.x = bound velocity.x, -max, max
    velocity.y = bound velocity.y, -max, max

  class Factory
    constructor: (@svg) ->
    player: ->
      ret = {}
      ret.position = new Position ret, 320, 320
      ret.hitbox = new Hitbox ret, 10
      ret.sprite = @svg.circle ret.position.x, ret.position.y, ret.hitbox.radius,
        fill: 'blue'
      return ret

    boss: ->
      ret = {}
      ret.position = new Position ret, 320, 80
      ret.hitbox = new Hitbox ret, 20
      ret.sprite = @svg.circle ret.position.x, ret.position.y, ret.hitbox.radius,
        fill: 'red'
      return ret

    doll: (boss) ->
      ret = {}
      ret.position = new Position ret, boss.position.x, boss.position.y
      ret.velocity = new Velocity ret, 5 - 10*Math.random(), 5 - 10*Math.random()
      ret.hitbox = new Hitbox ret, 5
      ret.sprite = @svg.circle ret.position.x, ret.position.y, ret.hitbox.radius,
        fill: 'red'
      return ret

  class World
    constructor: (svg) ->
      @factory = new Factory(svg)
      @player = @factory.player()
      @boss = @factory.boss()
      @dolls = []
      @t = 0
      @invincibleUntil = 240

      @mouse =
        x:@player.position.x
        y:@player.position.y
      $('#content').mousemove (e) =>
        offset = $('#content').offset()
        rad = @player.hitbox.radius
        @mouse.x = bound e.pageX - offset.left, rad, 640-rad
        @mouse.y = bound e.pageY - offset.top, rad, 480-rad
      @shoot = false
      $('#content').mousedown (e) =>
        @shoot = not @invincible()
      $('#content').mouseup (e) =>
        @shoot = false
    invincible: ->
      return @t <= @invincibleUntil
    tick: ->
      seek @player.position, 3, @mouse
      @player.sprite.setAttribute 'cx', @player.position.x
      @player.sprite.setAttribute 'cy', @player.position.y
      # player death
      collides = _.detect @dolls, (d) => d.hitbox.isCollision @player.hitbox
      if collides and not @invincible()
        @player.position.x = 320
        @player.position.y = 320
        @invincibleUntil = @t + 240

      @boss.position.x = 320 + 240 * Math.cos @t*Math.PI/240
      @boss.sprite.setAttribute 'cx',@boss.position.x

      if @t % (60*5) == 0
        @dolls.push @factory.doll @boss
        $('#count').text(@dolls.length)
        if @t == 0 then for i in [0...3]
          @dolls.push @factory.doll @boss

      for doll in @dolls
        if @shoot
          seekVelocity doll.velocity, doll.position, 0.1, @player.position
        doll.position.addXY doll.velocity.x, doll.velocity.y
        doll.sprite.setAttribute 'cx',doll.position.x
        doll.sprite.setAttribute 'cy',doll.position.y
        # bounce, and lose momentum.
        # lose momentum: dolls slowly 'calm down' when alice isn't under attack
        unless 0 < doll.position.x < 640
          doll.position.x = if doll.position.x < 0 then 0 else 640
          doll.velocity.x *= -0.4
        unless 0 < doll.position.y < 480
          doll.position.y = if doll.position.y < 0 then 0 else 480
          doll.velocity.y *= -0.4

      @t += 1

  onload = (svg) ->
    world = new World(svg)
    setInterval (->world.tick()), 16
  jQuery ($)->
    canvas = $('#content').svg(onLoad: onload)
