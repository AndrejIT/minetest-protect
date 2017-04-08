-- based on Zeg9's protector mod
-- based on glomie's mod of the same name
-- Released under WTFPL
-- Optimized for survival game server.
-- protects against placing tnt near protected area.
--Check if mods doors, signs, buckets, screwdrivers are fr4esh enough.

-- FIXME: use a mesh instead of the buggy wielditem, for protector_mese:display
-- but that isn't possible yet since models won't take care of the texture's alpha channel...


minetest.register_privilege("delprotect","Delete other's protection by sneaking")

protector = {}
protector.cache = {}
protector.radius = (tonumber(minetest.setting_get("protector_radius")) or 3)
protector.protectedspawnpos = (minetest.setting_get_pos("static_spawnpoint") or {x=0, y=3, z=0})

protector.node = "protector_mese:protect"
protector.node_b1 = "protector_mese:brazier_bronze"
protector.node_b2 = "protector_mese:brazier_gold"
protector.display = "protector_mese:display"
protector.display_node = "protector_mese:display_node"
protector.item = "protector_mese:stick"

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
	name=string.sub(name, 1, 30)	--protection
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
	local members = protector.get_member_list(meta)

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
protector.can_interact = function(r, pos, name, onlyowner, infolevel)
    local player
    if type(name) == "string" then
        player = minetest.get_player_by_name(name)
    elseif name and name:is_player() then
        player = name
        name = player:get_player_name()
    else
        return false
    end
    --fast check from cached data. no messages etc, just deny.
    if protector.cache[name..minetest.pos_to_string(pos)] then
        return false
    end

	if infolevel == nil then infolevel = 1 end
	-- Delprotect privileged users can override protections by holding sneak
	if minetest.get_player_privs( name ).delprotect and
	   player:get_player_control().sneak then
		return true
    end
	-- Find the protector nodes
	local positions = minetest.find_nodes_in_area(
		{x=pos.x-r, y=pos.y-r, z=pos.z-r},
		{x=pos.x+r, y=pos.y+r, z=pos.z+r},
		{protector.node, protector.node_b1, protector.node_b2})
	for _, pos in ipairs(positions) do
		local meta = minetest.get_meta(pos)
		local owner = meta:get_string("owner")
		if owner ~= name then
			if onlyowner or not protector.is_member(meta, name) then
				if infolevel == 1 then
					minetest.chat_send_player(name, "This area is owned by "..owner.." !")
				elseif infolevel == 2 then
					minetest.chat_send_player(name, "This area is owned by "..meta:get_string("owner")..".")
					if meta:get_string("members") ~= "" then
						minetest.chat_send_player(name, "Members are: "..meta:get_string("members")..".")
					end
				end
                protector.cache[name..minetest.pos_to_string(pos)] = 1
				return false
			end
		end
	end
	if infolevel == 2 then
		if #positions < 1 then
			minetest.chat_send_player(name, "This area is not protected.")
		else
			local meta = minetest.get_meta(positions[1])
			minetest.chat_send_player(name, "This area is owned by "..meta:get_string("owner")..".")
			if meta:get_string("members") ~= "" then
				minetest.chat_send_player(name,"Members are: "..meta:get_string("members")..".")
			end
		end
		minetest.chat_send_player(name,"You can build here.")
	end
	return true
end

if doors then
    --wooden door can be opened by registered persons
    local old_doors_on_rightclick_a=minetest.registered_nodes["doors:door_wood_a"].on_rightclick
    minetest.registered_nodes["doors:door_wood_a"].on_rightclick=function(pos, node, clicker)
        if protector.can_interact(protector.radius, pos, clicker) then
            return old_doors_on_rightclick_a(pos, node, clicker)
        else
            return
        end
    end
    local old_doors_on_rightclick_b=minetest.registered_nodes["doors:door_wood_b"].on_rightclick
    minetest.registered_nodes["doors:door_wood_b"].on_rightclick=function(pos, node, clicker)
        if protector.can_interact(protector.radius, pos, clicker) then
            return old_doors_on_rightclick_b(pos, node, clicker)
        else
            return
        end
    end
end --end doors

--additional protection against tnt!
if minetest.registered_nodes["tnt:tnt"] then
    protector.prot_tnt_radius_max = tonumber(minetest.setting_get("tnt_radius_max") or 25) + protector.radius
end --tnt

--for all "on_place" functions
local old_item_place = minetest.item_place
minetest.item_place = function(itemstack, placer, pointed_thing)
    local itemname = itemstack:get_name()
    local pos = pointed_thing.above
    if pos == nil then
        local name = placer:get_player_name()
        minetest.log("action", "Player "..name.." placing "..itemname.." without pos");
        return itemstack

    elseif itemname == protector.node then
        if not protector.can_interact(protector.radius*2, pos, placer, true) then
            return itemstack
        end
        if  protector.protectedspawnpos and
            pos.x > protector.protectedspawnpos.x - 121 and pos.x < protector.protectedspawnpos.x + 121 and
            pos.z > protector.protectedspawnpos.z - 121 and pos.z < protector.protectedspawnpos.z + 121 and
            not minetest.get_player_privs(placer:get_player_name()).delprotect
        then
            minetest.chat_send_player(placer:get_player_name(), "Spawn belongs to all!")
            return itemstack
        end
    elseif minetest.get_item_group(itemname, "protector") > 0 then
        if not protector.can_interact(protector.radius*2, pos, placer, true) then
            return itemstack
        end
        if  protector.protectedspawnpos and
            pos.x > protector.protectedspawnpos.x - 21 and pos.x < protector.protectedspawnpos.x + 21 and
            pos.z > protector.protectedspawnpos.z - 21 and pos.z < protector.protectedspawnpos.z + 21 and
            not minetest.get_player_privs(placer:get_player_name()).delprotect
        then
            minetest.chat_send_player(placer:get_player_name(), "Spawn belongs to all")
            return itemstack
        end
    elseif minetest.get_item_group(itemname, "sapling") > 0 then
        pos = {x=pos.x, y=pos.y+5, z=pos.z}
        if not protector.can_interact(protector.radius, pos, placer) then
            return itemstack
        end
    elseif itemname == "tnt:tnt" then
        if not protector.can_interact(protector.prot_tnt_radius_max or 25, pos, placer) then
            return itemstack
        end
    end

    return old_item_place(itemstack, placer, pointed_thing)
end


--"is_protected". not aware of item being placed or used
local old_is_protected = minetest.is_protected
function minetest.is_protected(pos, name)
    local node = minetest.get_node(pos)
    local nodename = node.name

    if nodename == protector.node then
        if not protector.can_interact(protector.radius, pos, name, true) then
            return true
        end
	elseif node.name == "bones:bones" then
		--protector has no effect on bones
	else
		if not protector.can_interact(protector.radius, pos, name) then
            return true
        end
	end

    return old_is_protected(pos, name)
end


local protect = {}
minetest.register_node(protector.node, {
	description = "Protection",
	tiles = {"protector_top.png","protector_top.png","protector_side.png"},
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate=2, protector=1},
	drawtype = "nodebox",
	node_box = {
		type="fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
	},
	selection_box = { type="regular" },
	paramtype = "light",
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
		meta:set_string("infotext", "Protection (owned by "..
				meta:get_string("owner")..")")
		meta:set_string("members", "")
		--meta:set_string("formspec",protector.generate_formspec(meta))
	end,
	on_rightclick = function(pos, node, clicker, itemstack)
		local meta = minetest.get_meta(pos)
		if protector.can_interact(1,pos,clicker,true) then
			minetest.show_formspec(
				clicker:get_player_name(),
				"protector_"..minetest.pos_to_string(pos),
				protector.generate_formspec(meta)
			)
		end
	end,
	on_punch = function(pos, node, puncher)
		if not protector.can_interact(1,pos,puncher,true) then
			return
		end
		local objs = minetest.get_objects_inside_radius(pos,.5) -- a radius of .5 since the entity serialization seems to be not that precise
		local removed = false

		for _, o in pairs(objs) do
			if o and not o:is_player() and o:get_luaentity().name == protector.display then
				o:remove()
				removed = true
			end
		end
		if not removed then -- nothing was removed: there wasn't the entity
			minetest.add_entity(pos, protector.display)
		end
	end,
})

minetest.register_node(protector.node_b1, {
	description = "Protection bronze brazier",
    drawtype = "plantlike",
	tiles = {
        {
            name = "protector_brazier_bronze_animated.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 3.0
            },
        }
    },
    inventory_image = "protector_brazier_bronze.png",
    wield_image = "protector_brazier_bronze.png",
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate=2, protector=1},
	node_box = {
		type="fixed",
		fixed = { -0.4, -0.5, -0.4, 0.4, -0.2, 0.4 },
	},
	selection_box = {
		type="fixed",
		fixed = { -0.4, -0.5, -0.4, 0.4, -0.2, 0.4 },
	},
    sunlight_propagates = true,
    is_ground_content = false,
    paramtype = "light",
    light_source = default.LIGHT_MAX - 1,
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
		meta:set_string("infotext", "Protection (owned by "..
				meta:get_string("owner")..")")
		meta:set_string("members", "")
		--meta:set_string("formspec",protector.generate_formspec(meta))
	end,
	on_rightclick = function(pos, node, clicker, itemstack)
		local meta = minetest.get_meta(pos)
		if protector.can_interact(1,pos,clicker,true) then
			minetest.show_formspec(
				clicker:get_player_name(),
				"protector_"..minetest.pos_to_string(pos),
				protector.generate_formspec(meta)
			)
		end
	end,
	on_punch = function(pos, node, puncher)
		if not protector.can_interact(1,pos,puncher,true) then
			return
		end
		local objs = minetest.get_objects_inside_radius(pos,.5) -- a radius of .5 since the entity serialization seems to be not that precise
		local removed = false

		for _, o in pairs(objs) do
			if o and not o:is_player() and o:get_luaentity().name == protector.display then
				o:remove()
				removed = true
			end
		end
		if not removed then -- nothing was removed: there wasn't the entity
			minetest.add_entity(pos, protector.display)
		end
	end,
    on_construct = function(pos)
        minetest.get_node_timer(pos):start(86400)
    end,
    on_timer = function(pos, elapsed)
        local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Extinct brazier")
        minetest.swap_node(pos, {name=protector.node_b1.."_extinct"});
        return false
    end,
})

minetest.register_node(protector.node_b1.."_extinct", {
	description = "Extinct bronze brazier",
    drawtype = "plantlike",
	tiles = {
        {
            name = "extinct_brazier_bronze.png",
        }
    },
    inventory_image = "extinct_brazier_bronze.png",
    wield_image = "extinct_brazier_bronze.png",
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate=2,},
	node_box = {
		type="fixed",
		fixed = { -0.4, -0.5, -0.4, 0.4, -0.2, 0.4 },
	},
	selection_box = {
		type="fixed",
		fixed = { -0.4, -0.5, -0.4, 0.4, -0.2, 0.4 },
	},
    sunlight_propagates = true,
    is_ground_content = false,
    paramtype = "light",
    light_source = 1,
})

minetest.register_node(protector.node_b2, {
	description = "Protection golden brazier",
    drawtype = "plantlike",
	tiles = {
        {
            name = "protector_brazier_gold_animated.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 3.0
            },
        }
    },
    inventory_image = "protector_brazier_gold.png",
    wield_image = "protector_brazier_gold.png",
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate=2, protector=1},
	node_box = {
		type="fixed",
		fixed = { -0.4, -0.5, -0.4, 0.4, -0.2, 0.4 },
	},
	selection_box = {
		type="fixed",
		fixed = { -0.4, -0.5, -0.4, 0.4, -0.2, 0.4 },
	},
    sunlight_propagates = true,
    is_ground_content = false,
    paramtype = "light",
    light_source = default.LIGHT_MAX,
	after_place_node = function(pos, placer)
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", placer:get_player_name() or "")
		meta:set_string("infotext", "Protection (owned by "..
				meta:get_string("owner")..")")
		meta:set_string("members", "")
		--meta:set_string("formspec",protector.generate_formspec(meta))
	end,
	on_rightclick = function(pos, node, clicker, itemstack)
		local meta = minetest.get_meta(pos)
		if protector.can_interact(1,pos,clicker,true) then
			minetest.show_formspec(
				clicker:get_player_name(),
				"protector_"..minetest.pos_to_string(pos),
				protector.generate_formspec(meta)
			)
		end
	end,
	on_punch = function(pos, node, puncher)
		if not protector.can_interact(1,pos,puncher,true) then
			return
		end
		local objs = minetest.get_objects_inside_radius(pos,.5) -- a radius of .5 since the entity serialization seems to be not that precise
		local removed = false

		for _, o in pairs(objs) do
			if o and not o:is_player() and o:get_luaentity().name == protector.display then
				o:remove()
				removed = true
			end
		end
		if not removed then -- nothing was removed: there wasn't the entity
			minetest.add_entity(pos, protector.display)
		end
	end,
    on_construct = function(pos)
        minetest.get_node_timer(pos):start(604800)
    end,
    on_timer = function(pos, elapsed)
        local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Extinct brazier")
        minetest.swap_node(pos, {name=protector.node_b2.."_extinct"})
        return false
    end,
})

minetest.register_node(protector.node_b2.."_extinct", {
	description = "Extinct golden brazier",
    drawtype = "plantlike",
	tiles = {
        {
            name = "extinct_brazier_gold.png",
        }
    },
    inventory_image = "extinct_brazier_gold.png",
    wield_image = "extinct_brazier_gold.png",
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate=2, },
	node_box = {
		type="fixed",
		fixed = { -0.4, -0.5, -0.4, 0.4, -0.2, 0.4 },
	},
	selection_box = {
		type="fixed",
		fixed = { -0.4, -0.5, -0.4, 0.4, -0.2, 0.4 },
	},
    sunlight_propagates = true,
    is_ground_content = false,
    paramtype = "light",
    light_source = 1,
})

minetest.register_on_player_receive_fields(function(player,formname,fields)
	if string.sub(formname,0,string.len("protector_")) == "protector_" then
		local pos_s = string.sub(formname,string.len("protector_")+1)
		local pos = minetest.string_to_pos(pos_s)
		local meta = minetest.get_meta(pos)
		if not protector.can_interact(1,pos,player,true) then
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
		protector.can_interact(protector.radius, pointed_thing.under,user,false,2)
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

minetest.register_craft({
	output = protector.node_b1,
	recipe = {
		{"","",""},
		{"default:bronze_ingot","default:coal_lump","default:bronze_ingot"},
		{"","default:bronze_ingot",""},
	}
})
minetest.register_craft({
	output = protector.node_b1,
	recipe = {
        {'default:coal_lump'},
		{protector.node_b1.."_extinct"},
	}
})
minetest.register_craft({
	output = protector.node_b2,
	recipe = {
		{"","",""},
		{"default:gold_ingot","default:coalblock","default:gold_ingot"},
		{"","default:gold_ingot",""},
	}
})
minetest.register_craft({
	output = protector.node_b2,
	recipe = {
        {'default:coalblock'},
		{protector.node_b2.."_extinct"},
	}
})

minetest.register_entity(protector.display, {
	physical = false,
	collisionbox = {0,0,0,0,0,0},
	visual = "wielditem",
	visual_size = {x=1.0/1.5,y=1.0/1.5}, -- wielditem seems to be scaled to 1.5 times original node size
	textures = {protector.display_node},
	on_step = function(self, dtime)
		self.timer = (self.timer or 0) + dtime
		if self.timer > 10 then
			self.object:remove()
		end
	end,
})

-- Display-zone node.
-- Do NOT place the display as a node
-- it is made to be used as an entity (see above)
local x = protector.radius
minetest.register_node(protector.display_node, {
	tiles = {"protector_display.png"},
	use_texture_alpha = true,
	walkable = false,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {

			-- sides
			{-(x+.55), -(x+.55), -(x+.55), -(x+.45), (x+.55), (x+.55)},
			{-(x+.55), -(x+.55), (x+.45), (x+.55), (x+.55), (x+.55)},
			{(x+.45), -(x+.55), -(x+.55), (x+.55), (x+.55), (x+.55)},
			{-(x+.55), -(x+.55), -(x+.55), (x+.55), (x+.55), -(x+.45)},
			-- top
			{-(x+.55), (x+.45), -(x+.55), (x+.55), (x+.55), (x+.55)},
			-- bottom
			{-(x+.55), -(x+.55), -(x+.55), (x+.55), -(x+.45), (x+.55)},
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

--clean protection cache
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 3 then
        protector.cache = {}
		timer = 0
	end
end)

minetest.register_abm{
	nodenames = {protector.node_b1, protector.node_b2},
	interval = 600,
	chance = 1,
	action = function(pos)
        local timeout = minetest.get_node_timer(pos):get_timeout();
        if timeout > 0 then
            local elapsed = minetest.get_node_timer(pos):get_elapsed();
            local hours_left = math.floor((timeout - elapsed) / 3600);
            local meta = minetest.get_meta(pos)
    		meta:set_string("infotext", "Protection (owned by "..
    				meta:get_string("owner")..")"..". Less than "..hours_left.."h left.")
        else
            local meta = minetest.get_meta(pos)
    		meta:set_string("infotext", "Protection (owned by "..meta:get_string("owner")..")")
        end
	end,
}
