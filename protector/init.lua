-- Zeg9's protector mod
-- based on glomie's mod of the same name
-- Released under WTFPL
-- Andrey added some changes to fit survival world needs
-- Doors and signs needs testing. Chest protection too complicated. bucket protection added. screwdriver protection.

-- FIXME: use a mesh instead of the buggy wielditem, for protector:display
-- but that isn't possible yet since models won't take care of the texture's alpha channel...


minetest.register_privilege("delprotect","Delete other's protection by sneaking")

protector = {}

protector.node = "protector:protect"
protector.item = "protector:stick"

protector.get_member_list = function(meta)
	local s = meta:get_string("members")
	local list = s:split(" ")
	return list
end

protector.set_member_list = function(meta, list)
	meta:set_string("members", table.concat(list, " "))
end

protector.is_member = function (meta, name)
	local list = protector.get_member_list(meta)
	for _, n in ipairs(list) do
		if n == name then
			return true
		end
	end
	return false
end

protector.add_member = function(meta, name)
	if protector.is_member(meta, name) then return end
	local list = protector.get_member_list(meta)
	table.insert(list,name)
	protector.set_member_list(meta,list)
end

protector.del_member = function(meta,name)
	local list = protector.get_member_list(meta)
	for i, n in ipairs(list) do
		if n == name then
			table.remove(list, i)
			break
		end
	end
	protector.set_member_list(meta,list)
end

protector.generate_formspec = function (meta)
	local formspec = "size[8,8]"
		.."label[0,0;-- protector interface --]"
		.."label[0,1;Punch the node to show the protected area.]"
		.."label[0,2;Current members:]"
	members = protector.get_member_list(meta)
	
	local npp = 15 -- names per page, for the moment is 4*4 (-1 for the + button)
	--no pages. 15 members max
	local i = 0
	for _, member in ipairs(members) do
		if i < 15 then
			formspec = formspec .. "button["..(i%4*2)..","..math.floor(i/4+3)..";1.5,.5;protector_member;"..member.."]"
			formspec = formspec .. "button["..(i%4*2+1.25)..","..math.floor(i/4+3)..";.75,.5;protector_del_member_"..member..";X]"
		end
		i = i +1
	end
	if i < npp then
		formspec = formspec
			.."field["..(i%4*2+1/3)..","..(math.floor(i/4+3)+1/3)..";1.433,.5;protector_add_member;;]"
			.."button["..(i%4*2+1.25)..","..math.floor(i/4+3)..";.75,.5;protector_submit;+]"
	end
	
	formspec = formspec .. "button_exit[1,7;3,1;protector_close;CLOSE]"

	return formspec
end

-- r: radius to check for protects
-- Infolevel:
-- * 0 for no info
-- * 1 for "This area is owned by <owner> !" if you can't dig
-- * 2 for "This area is owned by <owner>.
--   Members are: <members>.", even if you can dig
protector.can_dig = function(r,pos,digger,onlyowner,infolevel)
	if infolevel == nil then infolevel = 1 end
	if not digger or not digger.get_player_name then return false end
	-- Delprotect privileged users can override protections by holding sneak
	if minetest.get_player_privs(digger:get_player_name()).delprotect and
	   digger:get_player_control().sneak then
		return true end
	-- Find the protector nodes
	local positions = minetest.find_nodes_in_area(
		{x=pos.x-r, y=pos.y-r, z=pos.z-r},
		{x=pos.x+r, y=pos.y+r, z=pos.z+r},
		protector.node)
	for _, pos in ipairs(positions) do
		local meta = minetest.env:get_meta(pos)
		local owner = meta:get_string("owner")
		if owner ~= digger:get_player_name() then 
			if onlyowner or not protector.is_member(meta, digger:get_player_name()) then
				if infolevel == 1 then
					minetest.chat_send_player(digger:get_player_name(), "This area is owned by "..owner.." !")
				elseif infolevel == 2 then
					minetest.chat_send_player(digger:get_player_name(),"This area is owned by "..meta:get_string("owner")..".")
					if meta:get_string("members") ~= "" then
						minetest.chat_send_player(digger:get_player_name(),"Members are: "..meta:get_string("members")..".")
					end
				end
				return false
			end
		end
	end
	if infolevel == 2 then
		if #positions < 1 then
			minetest.chat_send_player(digger:get_player_name(),"This area is not protected.")
		else
			local meta = minetest.env:get_meta(positions[1])
			minetest.chat_send_player(digger:get_player_name(),"This area is owned by "..meta:get_string("owner")..".")
			if meta:get_string("members") ~= "" then
				minetest.chat_send_player(digger:get_player_name(),"Members are: "..meta:get_string("members")..".")
			end
		end
		minetest.chat_send_player(digger:get_player_name(),"You can build here.")
	end
	return true
end


--monkey patch
local old_sign_on_receive_fields=minetest.registered_nodes["default:sign_wall"].on_receive_fields
minetest.registered_nodes["default:sign_wall"].on_receive_fields=function(pos, formname, fields, sender)
	if protector.can_dig(3,pos,sender) then
		return old_sign_on_receive_fields(pos, formname, fields, sender)
	else
		return true
	end
end
--duck punching
local old_doors_on_place=minetest.registered_craftitems["doors:door_wood"].on_place
minetest.registered_craftitems["doors:door_wood"].on_place=function(itemstack, placer, pointed_thing)
	local pos = pointed_thing.above
	if protector.can_dig(3,pos,placer) then
		return old_doors_on_place(itemstack, placer, pointed_thing)
	else
		return itemstack
	end
end
local old_doors_on_place=minetest.registered_craftitems["doors:door_steel"].on_place
minetest.registered_craftitems["doors:door_steel"].on_place=function(itemstack, placer, pointed_thing)
	local pos = pointed_thing.above
	if protector.can_dig(3,pos,placer) then
		return old_doors_on_place(itemstack, placer, pointed_thing)
	else
		return itemstack
	end
end
--shaking the bag
local old_doors_on_rightclick_b_1=minetest.registered_nodes["doors:door_wood_b_1"].on_rightclick
minetest.registered_nodes["doors:door_wood_b_1"].on_rightclick=function(pos, node, clicker)
	if protector.can_dig(3,pos,clicker) then
		return old_doors_on_rightclick_b_1(pos, node, clicker)
	else
		return
	end
end
local old_doors_on_rightclick_t_1=minetest.registered_nodes["doors:door_wood_t_1"].on_rightclick
minetest.registered_nodes["doors:door_wood_t_1"].on_rightclick=function(pos, node, clicker)
	if protector.can_dig(3,pos,clicker) then
		return old_doors_on_rightclick_t_1(pos, node, clicker)
	else
		return
	end
end
local old_doors_on_rightclick_b_2=minetest.registered_nodes["doors:door_wood_b_2"].on_rightclick
minetest.registered_nodes["doors:door_wood_b_2"].on_rightclick=function(pos, node, clicker)
	if protector.can_dig(3,pos,clicker) then
		return old_doors_on_rightclick_b_2(pos, node, clicker)
	else
		return
	end
end
local old_doors_on_rightclick_t_2=minetest.registered_nodes["doors:door_wood_t_2"].on_rightclick
minetest.registered_nodes["doors:door_wood_t_2"].on_rightclick=function(pos, node, clicker)
	if protector.can_dig(3,pos,clicker) then
		return old_doors_on_rightclick_t_2(pos, node, clicker)
	else
		return
	end
end
--shaking the bag with screwdriver
local old_screwdriver_on_use=minetest.registered_tools["screwdriver:screwdriver"].on_use
minetest.registered_tools["screwdriver:screwdriver"].on_use=function(itemstack, user, pointed_thing)
	local pos = pointed_thing.under
	if pos==nil then
		return itemstack
	end
	if protector.can_dig(3,pos,user) then
		return old_screwdriver_on_use(itemstack, user, pointed_thing)
	else
		return itemstack
	end
end
for i = 1, 4 do
	local old_screwdriver_on_use=minetest.registered_tools["screwdriver:screwdriver"..i].on_use
	minetest.registered_tools["screwdriver:screwdriver"..i].on_use=function(itemstack, user, pointed_thing)
		local pos = pointed_thing.under
		if pos==nil then
			return itemstack
		end
		if protector.can_dig(3,pos,user) then
			return old_screwdriver_on_use(itemstack, user, pointed_thing)
		else
			return itemstack
		end
	end
end
--duck punching with bucket
local old_bucket_on_use=minetest.registered_craftitems["bucket:bucket_empty"].on_use
minetest.registered_craftitems["bucket:bucket_empty"].on_use=function(itemstack, placer, pointed_thing)
	local pos = pointed_thing.above
	if pos==nil then
		return itemstack
	end
	if protector.can_dig(4,pos,placer) then
		return old_bucket_on_use(itemstack, placer, pointed_thing)
	else
		return itemstack
	end
end
local old_bucket_water_on_place=minetest.registered_craftitems["bucket:bucket_water"].on_place
minetest.registered_craftitems["bucket:bucket_water"].on_place=function(itemstack, placer, pointed_thing)
	local pos = pointed_thing.above
	if protector.can_dig(4,pos,placer) then
		return old_bucket_water_on_place(itemstack, placer, pointed_thing)
	else
		return itemstack
	end
end
local old_bucket_lava_on_place=minetest.registered_craftitems["bucket:bucket_lava"].on_place
minetest.registered_craftitems["bucket:bucket_lava"].on_place=function(itemstack, placer, pointed_thing)
	local pos = pointed_thing.above
	if protector.can_dig(4,pos,placer) then
		return old_bucket_lava_on_place(itemstack, placer, pointed_thing)
	else
		return itemstack
	end
end

--wsn't me!
local old_node_dig = minetest.node_dig
function minetest.node_dig(pos, node, digger)
	local ok=true
	if node.name == "bones:bones" then
		ok=true
	else
		if node.name ~= protector.node then
			ok = protector.can_dig(3,pos,digger)
		else
			ok = protector.can_dig(3,pos,digger,true)
		end
	end
	if ok == true then
		old_node_dig(pos, node, digger)
	end
end

local old_node_place = minetest.item_place
function minetest.item_place(itemstack, placer, pointed_thing)
	if itemstack:get_definition().type == "node" then
		local ok=true
		if itemstack:get_name() ~= protector.node then
			local pos = pointed_thing.above
			ok = protector.can_dig(3,pos,placer)
		else
			local pos = pointed_thing.above
			ok = protector.can_dig(6,pos,placer,true)
		end 
		if ok == true then
			return old_node_place(itemstack, placer, pointed_thing)
		else
			return
		end	
	end	
	return old_node_place(itemstack, placer, pointed_thing)
end

local protect = {}
minetest.register_node(protector.node, {
	description = "Protection",
	tiles = {"protector_top.png","protector_top.png","protector_side.png"},
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate=2},
	drawtype = "nodebox",
	node_box = {
		type="fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
	},
	selection_box = { type="regular" },
	paramtype = "light",
	after_place_node = function(pos, placer)
		local meta = minetest.env:get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
		meta:set_string("infotext", "Protection (owned by "..
				meta:get_string("owner")..")")
		meta:set_string("members", "")
		--meta:set_string("formspec",protector.generate_formspec(meta))
	end,
	on_rightclick = function(pos, node, clicker, itemstack)
		local meta = minetest.env:get_meta(pos)
		if protector.can_dig(1,pos,clicker,true) then
			minetest.show_formspec(
				clicker:get_player_name(),
				"protector_"..minetest.pos_to_string(pos),
				protector.generate_formspec(meta)
			)
		end
	end,
	on_punch = function(pos, node, puncher)
		if not protector.can_dig(1,pos,puncher,true) then
			return
		end
		local objs = minetest.env:get_objects_inside_radius(pos,.5) -- a radius of .5 since the entity serialization seems to be not that precise
		local removed = false
		for _, o in pairs(objs) do
			if (not o:is_player()) and o:get_luaentity().name == "protector:display" then
				o:remove()
				removed = true
			end
		end
		if not removed then -- nothing was removed: there wasn't the entity
			minetest.env:add_entity(pos, "protector:display")
		end
	end,
})
-- remove formspecs from older versions of the mod
--minetest.register_abm({
--	nodenames = {protector.node},
--	interval = 5.0,
--	chance = 1,
--	action = function(pos,...)
--		local meta = minetest.env:get_meta(pos)
--		meta:set_string("formspec","")
--	end,
--})
minetest.register_on_player_receive_fields(function(player,formname,fields)
	if string.sub(formname,0,string.len("protector_")) == "protector_" then
		local pos_s = string.sub(formname,string.len("protector_")+1)
		local pos = minetest.string_to_pos(pos_s)
		local meta = minetest.env:get_meta(pos)
		if not protector.can_dig(1,pos,player,true) then
			return
		end
		if fields.protector_add_member then
			for _, i in ipairs(fields.protector_add_member:split(" ")) do
				protector.add_member(meta,i)
			end
		end
		for field, value in pairs(fields) do
			if string.sub(field,0,string.len("protector_del_member_"))=="protector_del_member_" then
				protector.del_member(meta, string.sub(field,string.len("protector_del_member_")+1))
			end
		end
		if fields.protector_close then
			return
		end
		if not fields["quit"] then
			minetest.show_formspec(
				player:get_player_name(), formname,
				protector.generate_formspec(meta)
			)
		end
	end
end)

minetest.register_craftitem(protector.item, {
	description = "Protection tool",
	inventory_image = "protector_stick.png",
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type ~= "node" then
			return
		end
		protector.can_dig(3,pointed_thing.under,user,false,2)
	end,
})

minetest.register_craft({
	output = protector.node,
	recipe = {
		{"default:stone","default:stone","default:stone"},
		{"default:stone","default:mese","default:stone"},
		{"default:stone","default:stone","default:stone"},
	}
})
--reversable to mese
minetest.register_craft({
	output = "default:mese",
	recipe = {
		{protector.node,"",""},
		{"","",""},
		{"","",""},
	}
})
minetest.register_craft({
	output = protector.item,
	recipe = {
		{protector.node},
		{'default:stick'},
	}
})

minetest.register_entity("protector:display", {
	physical = false,
	collisionbox = {0,0,0,0,0,0},
	visual = "wielditem",
	visual_size = {x=1.0/1.5,y=1.0/1.5}, -- wielditem seems to be scaled to 1.5 times original node size
	textures = {"protector:display_node"},
	on_step = function(self, dtime)
		if minetest.get_node(self.object:getpos()).name ~= protector.node then
			self.object:remove()
			return
		end
	end,
})

-- Display-zone node.
-- Do NOT place the display as a node
-- it is made to be used as an entity (see above)
minetest.register_node("protector:display_node", {
	tiles = {"protector_display.png"},
	use_texture_alpha = true,
	walkable = false,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			-- sides
			{-3.55, -3.55, -3.55, -3.45, 3.55, 3.55},
			{-3.55, -3.55, 3.45, 3.55, 3.55, 3.55},
			{3.45, -3.55, -3.55, 3.55, 3.55, 3.55},
			{-3.55, -3.55, -3.55, 3.55, 3.55, -3.45},
			-- top
			{-3.55, 3.45, -3.55, 3.55, 3.55, 3.55},
			-- bottom
			{-3.55, -3.55, -3.55, 3.55, -3.45, 3.55},
			-- middle (surround protector)
			{-.55,-.55,-.55, .55,.55,.55},
		},
	},
	selection_box = {
		type = "regular",
	},
	paramtype = "light",
	groups = {dig_immediate=3,not_in_creative_inventory=1},
	drop = "",
})


