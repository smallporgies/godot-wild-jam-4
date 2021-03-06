extends "res://actors/physics/Physics.gd"

#Signals are great for calling methods in
#physics objects. Godot does not crash if it
#attempts to emit a signal inside a body
#that does not exist.
signal get_health
signal get_scale

#These are the constants that will always be
#affecting us.
const DOUBLE_JUMP = -1000
const JUMP_STRENGTH = -350
const JUMP_STAGE_1 = 0.011167 * 5
const JUMP_STAGE_2 = 0.011167 * 8
const JUMP_STAGE_3 = 0.011167 * 10
const JUMP_STAGE_MAX = 3

#This prevents the Snowman from walking or
#dashing.
export var can_navigate = true
var can_handle_input = true
export var has_camera = true
export var camera_limit_top : int = 0
export var camera_limit_left : int = 0
export var camera_limit_bottom : int = 10000
export var camera_limit_right : int = 10000

var can_jump = false


#State Machine
var FSM = {
	"Default" : "default",
	"Dash" : "dash",
	"Hitstun" : "hitstun",
	"Dead" : "dead"
	}
var fsm_state = "Default" 

#enum state {IDLE,RUN,JUMP,HURT,DEAD,DASH}
#var current_state = state.IDLE

#Determines the velocity
#var was_in_air = true

#Hitstun
const HITSTUN_WAIT = 0.011167 * 20
var hitstun_left = HITSTUN_WAIT

#Use this to determine jump height.
var jump_held : float = 0
var jump_stage : int = 1
var jump_mod : Array = [ 0, -140, -200, -300 ]

#This allows us to double jump.
signal jump
signal double_jump
var has_double_jump = true
var just_jumped = false
var check_just_jumped = false

#Dash variables
signal dash
const DASH_COOLDOWN_LENGTH = 0.051167 * 20
const DASH_DURATION = 0.011167 * 40
const DASH_SPEED = 500
const DASH_PUSHBACK = 30
var dash_cooldown = 0
var dash_lasted = 0
var dash_direction = 1

onready var original_scale = Vector2(scale.x, scale.y)
var size = 1;

#Death variables Wait this long before moving to game over.
var death_wait = 0.016667 * 60
var is_dead = false


func process_frame(delta):
	if can_navigate && can_handle_input :
		handle_input( delta )
		handle_jump_input()
	elif can_handle_input :
		handle_jump_input()
	call( "process_" + FSM[fsm_state], delta )



func _physics_process(delta):
	scale = original_scale * size


func _ready():
	emit_signal("get_health")
	emit_signal("get_scale")
	self.connect( "pushback", self, "pushback" )
	self.connect( "lost_all_health", self, "health_gone"  )
	self.connect( "health_changed", SnowmanStats, "change_health" )
	$AnimatedSprite.play()
	$DashFX.emitting = false
	$DoubleJumpFX.emitting = false
	$Camera2D.current = has_camera
	$Camera2D.limit_top = camera_limit_top
	$Camera2D.limit_left = camera_limit_left
	$Camera2D.limit_bottom = camera_limit_bottom
	$Camera2D.limit_right = camera_limit_right
	
	set_health( SnowmanStats.current_health )

func _on_health(amount):
	prints("health: ", amount)
	emit_signal("health_changed", amount)

func been_hit( push : Vector2, damageAmount = 0 ):
	#Start hitstun state.
	jump_held = 0
	can_handle_input = false
	can_jump = false
	fsm_state = "Hitstun"
	emit_signal( "dash", false )
	#if damageAmount > 0 :
	#	emit_signal( "change_anim", "Hit" )


func fully_dead():
	SceneBrowser.load_scene( "GameOver" )
	Transition.change_scene()


func handle_input( delta ):
	#Quick left right handling.
	#I will eventually replace this with
	#a controller input handling class.
	velocity.x = (int( Input.is_action_pressed("ui_right") ) - 
	int( Input.is_action_pressed( "ui_left" ) ) ) * 200
	
	# Controlling the direction that the dash will be performed based on the direction of the snowman
	# It's no longer necessary to hold down the direction button whilst dashing to prevent the snowman dashing right when facing left.
	if Input.is_action_pressed("ui_left"):
		dash_direction = -1
		
	elif Input.is_action_pressed("ui_right"):
		dash_direction = 1
	
	#Start a dash if player inputs it.
	if( Input.is_action_just_pressed("dash") &&
	dash_cooldown <= 0 ):
		emit_signal( "dash", true )
		fsm_state = "Dash"
		velocity.y = 0
		$DashHitbox.is_activated( true )
		$Hurtbox.is_activated( false )
	
	dash_cooldown = max( dash_cooldown - delta, 0 )


func handle_jump_input():
	#We need to check for jumpin.
	#Prevent myself from jumping and double 
	#jumping in one frame.
	if( Input.is_action_just_pressed( "jump" ) &&
	check_just_jumped == false ):
		just_jumped = true
		check_just_jumped = true
	elif( Input.is_action_pressed( "jump" ) &&
	check_just_jumped == true ):
		just_jumped = false
	elif( Input.is_action_pressed( "jump" ) == false ):
		check_just_jumped = false
		just_jumped = false

	
func health_gone():
	emit_signal("change_anim", "Dead")
	#My health has been depleted.
	#Play the death animation and die.
	
	#Prevent collisions from happening.
	for child in get_children() :
		if child.has_method( "is_activated" ) :
			child.is_activated( false )
	
	fsm_state = "Dead"
	can_navigate = false
	can_handle_input = false
	is_dead = true
	
	$AnimatedSprite.connect( "animation_finished", self, "fully_dead" )


func jump_held( delta ):
	#Determines how strong the jump should be.
	if Input.is_action_pressed( "jump" ) :
		jump_held += FRAME
		
		velocity.y = JUMP_STRENGTH + jump_mod[ jump_stage ] * size
		if jump_stage == 2 :
			pass  
		
		if jump_held >= get( "JUMP_STAGE_" + str( jump_stage ) ) :
			jump_stage += 1
			
			if jump_stage > JUMP_STAGE_MAX :
				jump_held = 0
				jump_stage = 1
	else:
		jump_held = 0
		jump_stage = 1


func move_body( move_by = velocity.rotated( slope() ), delta = FRAME ):
	move_and_slide_with_snap( (move_by.rotated( slope() ) / delta) * FRAME, Vector2( 0, -1 ), FLOOR )
	flip_h()


func process_dash( delta ):
	#Start a dash.
	can_handle_input = false
	dash_lasted += delta
	
	move_and_slide( Vector2( dash_direction * DASH_SPEED, 0 ) )
	
	if is_on_wall():
		can_handle_input = true
		self.position.x += DASH_PUSHBACK * sign(-dash_direction)
		fsm_state = "Default"
		dash_lasted = 0
		dash_cooldown = DASH_COOLDOWN_LENGTH
		$DashHitbox.is_activated( false )
		$Hurtbox.is_activated( true )
		emit_signal( "dash", false )
		return
	
	if dash_lasted >= DASH_DURATION :
		can_handle_input = true
		fsm_state = "Default"
		dash_lasted = 0
		dash_cooldown = DASH_COOLDOWN_LENGTH
		$DashHitbox.is_activated( false )
		$Hurtbox.is_activated( true )
		emit_signal( "dash", false )


func process_dead( delta ):
	#Make all enemies stop chasing me.
	get_tree().call_group( "Enemy", "chase_snowman", null )
	
	death_wait -= delta
	emit_signal( "change_anim", "Dead" )
	$Camera2D.zoom.x -= 0.003
	$Camera2D.zoom.y -= 0.003
	
	if death_wait <= 0 :
		set_health( 100 )
		SceneBrowser.load_scene("GameOver")


func process_default( delta ):
	if jump_held > 0 :
		jump_held( delta )
	
	handle_physics( delta )

	#Compute floor logic.
	if on_floor :
		has_double_jump = true
		jump_held = 0
		if just_jumped :
			velocity.y = JUMP_STRENGTH
			jump_held += delta
			emit_signal( "jump" )
	
	elif has_double_jump :
			if just_jumped :
				emit_signal( "double_jump" )
				has_double_jump = false
				velocity.y = DOUBLE_JUMP
				$DoubleJumpFX.emitting = true
	  
	move_body( velocity, delta)


func process_hitstun( delta ):
	#Move myself.
	move_body()
	
	can_handle_input = false
	
	#I am invincible until the hitstun
	#wears off.
	$Hurtbox.is_activated( false )
	$DashHitbox.is_activated( false )
	
	hitstun_left -= delta
	if hitstun_left <= 0 :
		can_handle_input = true
		hitstun_left = HITSTUN_WAIT
		fsm_state = "Default"
		if dash_lasted > 0 :
			self.position.x += DASH_PUSHBACK * sign(-dash_direction)
			dash_lasted = 0
		$Hurtbox.is_activated( true )


func slope():
	#Returns the slope's angle.
	var slope = Vector2( 0,0 )
	if $FloorLeft.is_colliding() :
		slope = $FloorLeft.get_collision_normal()
	
	elif $FloorRight.is_colliding() :
		slope = $FloorRight.get_collision_normal()
	
	return slope.rotated( 1.570796 ).angle() * int( allow_slope )

func _on_Fountain_fountain_entered():
	emit_signal("gain_health", 100)

func is_snowman():
	return