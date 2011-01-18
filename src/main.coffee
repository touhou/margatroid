
do ->
  console ?= {log:(->), info:(->), warn:(->),error:(->),trace:(->)}
  assert = (val, msg) ->
    unless val then throw new Error msg ? ''+val
    return val

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
    constructor: (@self, @g, @fn) ->
      @old = {}
    clear: (r) ->
      @g.clearRect @old.x-r-1, @old.y-r-1, 2*r+2,2*r+2
    destroy: ->
      #@fn.clear.call this
    draw: ->
      #@fn.clear.call this
      @fn.draw.call this
      @old.x = @self.position.x
      @old.y = @self.position.y
      return this

  class Factory
    constructor: (@g, @config) ->
    player: ->
      ret = {}
      ret.position = new Position ret, 320, 320
      ret.hitbox = new Hitbox ret, 10
      ret.render = new Render ret, @g,
        clear: -> @clear ret.hitbox.radius
        draw: ->
          r = ret.hitbox.radius
          @g.fillRect ret.position.x-r, ret.position.y-r, 2*r, 2*r
      return ret

    boss: ->
      ret = {}
      ret.position = new Position ret, 320, 80
      ret.hitbox = new Hitbox ret, 25
      sprite = assert $('#alice')[0]
      ret.render = new Render ret, @g,
        clear: -> @clear ret.hitbox.radius
        draw: ->
          @g.drawImage sprite, ret.position.x-45, ret.position.y-50
          #r = ret.hitbox.radius
          #@g.fillRect ret.position.x-r, ret.position.y-r, 2*r, 2*r
      ret.fullhealth = @config.boss.health
      ret.health = ret.fullhealth
      return ret

    doll: (boss, spriteref) ->
      ret = {}
      ret.position = new Position ret, boss.position.x, boss.position.y
      angle = 2 * Math.PI * Math.random()
      speed = 2 + 3*Math.random()
      ret.velocity = new Velocity ret, speed*Math.cos(angle), speed*Math.sin(angle)
      ret.hitbox = new Hitbox ret, 13
      ret.render = new Render ret, @g,
        clear: -> @clear ret.hitbox.radius
        draw: ->
          @g.drawImage spriteref(), ret.position.x-30, ret.position.y-32
          #r = ret.hitbox.radius
          #@g.fillRect ret.position.x-r, ret.position.y-r, 2*r, 2*r
      return ret
    bullet: (player, vx) ->
      ret = {}
      ret.position = new Position ret, player.position.x, player.position.y
      ret.velocity = new Velocity ret, vx, -8
      ret.hitbox = new Hitbox ret, 3
      sprite = assert $('#bullet')[0]
      ret.render = new Render ret, @g,
        clear: -> @clear ret.hitbox.radius
        draw: ->
          @g.drawImage sprite, ret.position.x-12, ret.position.y-12
          #r = ret.hitbox.radius
          #@g.fillRect ret.position.x-r, ret.position.y-r, 2*r, 2*r
      return ret
    dollmaker: (world) ->
      ret =
        # spawn a few extra dolls right away
        val: @config.dollmaker.start * @config.dollmaker.max
        sprite:
          fn: -> if world.shoot then @live else @dead
          live: assert $('#livedoll')[0], 'livedoll'
          dead: assert $('#deaddoll')[0], 'deaddoll'
        incr:
          normal: @config.dollmaker.incr.normal
          shooting: @config.dollmaker.incr.shooting
        max: @config.dollmaker.max
        tick: ->
          @val += if world.shoot then @incr.shooting else @incr.normal
          spawned = Math.floor @val / @max
          if spawned > 0
            @val -= spawned * @max
            while spawned > 0
              spawned -= 1
              world.dolls.push world.factory.doll world.boss, => @sprite.fn()
            $('#count').hide().text(world.dolls.length).fadeIn()
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
    constructor: (@canvas) ->
      @config = {}
      @g = canvas.getContext '2d'
      @factory = new Factory(@g, @config)
      @player = @factory.player()
      @t = 0
      @bullets = []
      @dolls = []

      @clearFoes()
      @clearPlayer()

      @mouse =
        x:@player.position.x
        y:@player.position.y
      $(document).mousemove (e) =>
        offset = $('#content').offset()
        rad = @player.hitbox.radius
        @mouse.x = bound e.pageX - offset.left, rad, 640-rad
        @mouse.y = bound e.pageY - offset.top, rad, 480-rad
      @shoot = false

    clearPlayer: (@lives=4) ->
      $('#lives').hide().text(@lives).fadeIn()
      for b in @bullets
        b.render.destroy()
      @bullets = []

      @vulnerable = @factory.cooldown this, 240
      @weapon = @factory.cooldown this, 5
      @paused = false

    clearFoes: (@stage=1) ->
      $('#stage').hide().text(@stage).fadeIn()
      _.extend @config,
        doll:
          # Stage 1: velocity == 0, dolls don't chase. Speed up every
          # 3 stages after that (2, 5, 8...)
          seekVelocity: 0 + 0.03 * Math.floor (@stage+1) / 3
        boss:
          # Boss health increases a little every stage.
          health: 30 + @stage * 2
          # Boss speed increases a little every stage. This is also a
          # nice hack to make the boss spawn at a 'different' location
          # when killed, without bothering with randomness.
          speed: (4 + @stage) / 240 / 7
        dollmaker:
          # Start out with 4 dolls per turn. From stage 3 (5 dolls),
          # increase starting dolls by 1 per 5 rounds (3, 8, 13...)
          start: 4 + Math.floor (@stage + 2)/5
          # Spawn dolls a little faster every round. Power fns so it's
          # a percentage faster every time, and high levels don't have
          # huge jumps relative to early levels, or have (for example)
          # level 100 spawn infinite dolls per frame.
          max: Math.floor 3333 * Math.pow 0.96, @stage-1
          incr:
            # Normal spawn rate is a baseline.
            normal: 5
            # Spawn even faster while the player shoots, a little
            # faster every few rounds (7, 14, 21...)
            shooting: 50 + 10*((Math.floor (stage-1)/7) or 0)
      console.log 'hi', @stage, JSON.stringify @config

      if @boss?
        @boss.render.destroy()
      @boss = @factory.boss()
      for d in @dolls
        d.render.destroy()
      @dolls = []

      @dollmaker = @factory.dollmaker this

    start: ->
      $(document).bind 'keydown.pause', (e) =>
        if e.which == 27 # esc
          @paused = not @paused
          if @paused
            $('#paused').fadeIn()
          else
            $('#paused').fadeOut()
      $('#content').mousedown (e) =>
        if @paused then return
        @shoot = true
        $('#living').fadeIn('fast')
        $('#nonliving').fadeOut('fast')
        return false
      $('#content').mouseup (e) =>
        if @paused then return
        @shoot = false
        $('#living, #nonliving').stop(true,true)
        $('#living').fadeOut('fast')
        $('#nonliving').fadeIn('fast')

    gameover: ->
      $(document).unbind 'keydown.pause'
      @paused = true
      $('#gameover').fadeIn('slow')

    tick: ->
      if @paused then return
      # player movement
      seek @player.position, 5, @mouse
      # player bullets
      if @shoot and @weapon.isReady()
        @bullets.push @factory.bullet @player, -1
        @bullets.push @factory.bullet @player, 0
        @bullets.push @factory.bullet @player, 1
        @weapon.clear()
      bs = []
      for bullet in @bullets
        bullet.position.addXY bullet.velocity.x, bullet.velocity.y
        # If it hits the boss, damage the boss and kill the bullet
        if bullet.hitbox.isCollision @boss.hitbox
          @boss.health -= 1
          bullet.render.destroy()
        # If it's still in the playing field, keep it
        else if bullet.position.y < 0
          bullet.render.destroy()
        else
          bs.push bullet
      @bullets = bs
      healthpct = Math.max 0, @boss.health/@boss.fullhealth
      $('#healthgone').css(width:(100 * (1 - healthpct))+'%')
      # boss death
      if healthpct == 0
        @boss.render.destroy()
        # extra lives for beating stages
        if @stage == 1 or @stage % 3 == 0
          @lives += 1
          $('#lives').hide().text(@lives).fadeIn()
        @clearFoes @stage+1

      # player death
      if @vulnerable.isReady()
        collides = _.detect @dolls, (d) => d.hitbox.isCollision @player.hitbox
        if collides
          @lives -= 1
          $('#lives').hide().text(@lives).fadeIn()
          @vulnerable.clear()
          @player.position.setXY 320, 320
          if @lives < 0
            @gameover()

      @boss.position.setXY (320 + 240 * Math.sin @t*Math.PI*@config.boss.speed), @boss.position.y
      @dollmaker.tick()

      for doll in @dolls
        if @shoot
          seekVelocity doll.velocity, doll.position, @config.doll.seekVelocity, @player.position
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

      # Draw everything
      @g.clearRect 0, 0, 640, 480 #TODO dirty rects
      for d in @dolls
        d.render.draw()
      for b in @bullets
        b.render.draw()
      @boss.render.draw()
      @player.render.draw()

      # Finally done
      @t += 1

  onload = (canvas) ->
    world = new World canvas
    $(document).bind 'click.intro', ->
      $(document).unbind 'click.intro'
      $('#intro').fadeOut()
      setInterval (->world.tick()), 16
      world.start()

  jQuery ($)->
    onload $('#content canvas')[0]
