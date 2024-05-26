extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var player_name_input = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/PlayerName
@onready var main_camera = $MainCamera
@onready var hud = $CanvasLayer/HUD

@onready var hp = $CanvasLayer/HUD/HP
@onready var hp_text = $CanvasLayer/HUD/HP/HPText
@onready var death_count = $CanvasLayer/HUD/DeathCount
@onready var kill_count = $CanvasLayer/HUD/KillCount


const Player = preload("res://player.tscn")
const PORT = 1234
var enet_peer = ENetMultiplayerPeer.new()
var upnp = UPNP.new()

func _on_host_button_pressed():

	main_menu.hide()
	hud.show()
	death_count.text = "deaths : "
	kill_count.text = "kills : "
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())
	upnp_setup()

func _on_join_button_pressed():

	main_menu.hide()
	hud.show()
	death_count.text = "deaths : "
	kill_count.text = "kills : "
	enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer
	#add_player(multiplayer.get_unique_id())

func add_player(peer_id):
	
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)
		player.death_count_changed.connect(update_death_count)
		player.kill_count_changed.connect(update_kill_count)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func upnp_setup():

	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s:%d" % [upnp.query_external_address(), PORT])
	
	
func update_health_bar(health_value):
		hp.value = health_value
		hp_text.text = str(health_value)

func update_death_count(deaths):
	death_count.text = "deaths : "+ str(deaths)
	
func update_kill_count(kills):
	kill_count.text = "kills : "+ str(kills)
	
func _exit_tree():
	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		var unmap_result = upnp.delete_port_mapping(PORT)
		if unmap_result != UPNP.UPNP_RESULT_SUCCESS:
			print("UPNP Port Unmapping Failed! Error %s" % unmap_result)
		else:
			print("UPNP Port Unmapped Successfully.")

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)
		node.death_count_changed.connect(update_death_count)
		node.kill_count_changed.connect(update_kill_count)

