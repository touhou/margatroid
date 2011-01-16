
do ->
  assert = (val, msg) ->
    unless val then throw new Error msg

  # 2D coordinates
  class Position
    constructor: (@self, @x, @y) ->
      @event = $({})
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
      @setXY @x+dx, @y+dy
    setXY: (@x, @y) ->
      @event.trigger 'move', this
      return this
  class Velocity extends Position

  bound = (val, min, max) ->
    return Math.min max, Math.max min, val

  # This can collide with stuff
  class Hitbox
    constructor: (@self, @radius) ->
    isCollision: (that) ->
      distance = @self.position.distance that.self.position
      allowed = @radius + that.radius
      return allowed >= distance

  # Move a point towards another point at a fixed speed. (Player
  # follows the mouse.)
  seek = (position, speed, target) ->
    distance = position.distance target
    if distance <= speed
      position.setXY target.x, target.y
    else
      trig = position.trig target
      position.addXY -trig.cos * speed, -trig.sin * speed
  # Like seek, changing velocity instead of position. (Dolls chase the
  # player.) You'll overshoot the target - this is intentional. You
  # can get going REALLY fast with this - not quite intentional, but
  # the momentum-absorbing walls mitigate the worst of it; not worth
  # fixing.
  seekVelocity = (velocity, position, speed, target) ->
    trig = position.trig target
    velocity.addXY -trig.cos * speed, -trig.sin * speed

  # Draw something at a position, updating it when moved.
  class Render
    constructor: (@self, @svg, @sprite, onMove=->) ->
      @self.position.event.bind 'move', (e, args) =>
        @sprite.setAttribute 'cx', @self.position.x
        @sprite.setAttribute 'cy', @self.position.y
        onMove this
    destroy: ->
      @svg.remove @sprite

  class Factory
    constructor: (@svg) ->
    player: ->
      ret = {}
      ret.position = new Position ret, 320, 320
      ret.hitbox = new Hitbox ret, 10
      ret.render = new Render ret, @svg, @svg.circle ret.position.x, ret.position.y, ret.hitbox.radius,
        fill: 'blue'
      return ret

    boss: ->
      ret = {}
      ret.position = new Position ret, 320, 80
      ret.hitbox = new Hitbox ret, 20
      ret.render = new Render ret, @svg, @svg.circle ret.position.x, ret.position.y, ret.hitbox.radius,
        fill: 'red'
      ret.health = 250
      return ret

    doll: (boss) ->
      ret = {}
      ret.position = new Position ret, boss.position.x, boss.position.y
      angle = 2 * Math.PI * Math.random()
      speed = 2 + 3*Math.random()
      ret.velocity = new Velocity ret, speed*Math.cos(angle), speed*Math.sin(angle)
      ret.hitbox = new Hitbox ret, 5
      ret.render = new Render ret, @svg, @svg.circle ret.position.x, ret.position.y, ret.hitbox.radius,
        fill: 'red'
      return ret
    bullet: (player) ->
      ret = {}
      ret.position = new Position ret, player.position.x, player.position.y
      ret.velocity = new Velocity ret, 0, -8
      ret.hitbox = new Hitbox ret, 3
      ret.render = new Render ret, @svg, @svg.circle ret.position.x, ret.position.y, ret.hitbox.radius,
        fill: 'blue'
      return ret
    dollmaker: (world) ->
      ret =
        # spawn a few extra dolls right away
        val: 1200
        incr:
          normal: 1
          shooting: 5
        max: 300
        tick: ->
          @val += if world.shoot then @incr.shooting else @incr.normal
          if @val >= @max
            @val -= @max
            world.dolls.push world.factory.doll world.boss
            $('#count').text(world.dolls.length)
      return ret
    cooldown: (world, cooldown) ->
      ret =
        cooldown: cooldown
        isReady: ->
          return world.t >= @until
        clear: ->
          @until = world.t + @cooldown
      ret.clear()
      return ret

  class World
    constructor: (svg) ->
      @factory = new Factory(svg)
      @player = @factory.player()
      @bullets = []
      @boss = @factory.boss()
      @dollmaker = @factory.dollmaker this
      @dolls = []
      @t = 0
      @vulnerable = @factory.cooldown this, 240
      @weapon = @factory.cooldown this, 5
      @paused = false

      $(document).keydown (e) =>
        if e.which == 27 # esc
          @paused = not @paused
          if @paused
            $('#paused').show(400)
          else
            $('#paused').hide()

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
        @shoot = true
      $('#content').mouseup (e) =>
        @shoot = false
    tick: ->
      if @paused then return
      # player movement
      seek @player.position, 5, @mouse
      # player bullets
      if @shoot and @weapon.isReady()
        @bullets.push @factory.bullet @player
        @weapon.clear()
      bs = []
      for bullet in @bullets
        bullet.position.addXY bullet.velocity.x, bullet.velocity.y
        # If it hits the boss, damage the boss and kill the bullet
        if bullet.hitbox.isCollision @boss.hitbox
          bullet.render.destroy()
          @boss.health -= 1
        # If it's left the playing field, kill it
        else if bullet.position.y < 0
          bullet.render.destroy()
        # else, it stays in play
        else
          bs.push bullet
      @bullets = bs
      # player death
      if @vulnerable.isReady()
        collides = _.detect @dolls, (d) => d.hitbox.isCollision @player.hitbox
        if collides
          @vulnerable.clear()
          @player.position.setXY 320, 320

      @boss.position.setXY (320 + 240 * Math.sin @t*Math.PI/240), @boss.position.y
      @dollmaker.tick()

      for doll in @dolls
        if @shoot
          seekVelocity doll.velocity, doll.position, 0.1, @player.position
        doll.position.addXY doll.velocity.x, doll.velocity.y
        # bounce, and lose momentum.
        # lose momentum: dolls slowly 'calm down' when alice isn't under attack
        elasticity = -0.4 - 0.2*Math.random()
        unless 0 < doll.position.x < 640
          doll.position.x = if doll.position.x < 0 then 0 else 640
          doll.velocity.x *= elasticity
        unless 0 < doll.position.y < 480
          doll.position.y = if doll.position.y < 0 then 0 else 480
          doll.velocity.y *= elasticity

      @t += 1

  onload = (svg) ->
    world = new World(svg)
    $(document).bind 'click.intro', ->
      $(document).unbind 'click.intro'
      $('#intro').hide(400)
      setInterval (->world.tick()), 16
  jQuery ($)->
    canvas = $('#content').svg(onLoad: onload)
