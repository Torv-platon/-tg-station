/obj/structure/grille
	desc = "A flimsy lattice of metal rods, with screws to secure it to the floor."
	name = "grille"
	icon = 'icons/obj/structures.dmi'
	icon_state = "grille"
	density = 1
	anchored = 1
	flags = CONDUCT
	pressure_resistance = 5*ONE_ATMOSPHERE
	layer = BELOW_OBJ_LAYER
	armor = list(melee = 50, bullet = 70, laser = 70, energy = 100, bomb = 10, bio = 100, rad = 100, fire = 0, acid = 0)
	obj_integrity = 50
	max_integrity = 50
	integrity_failure = 20
	var/obj/item/stack/rods/stored

/obj/structure/grille/New()
	..()
	stored = new/obj/item/stack/rods(src)
	stored.amount = 2

/obj/structure/grille/ratvar_act()
	if(broken)
		new /obj/structure/grille/ratvar/broken(src.loc)
	else
		new /obj/structure/grille/ratvar(src.loc)
	qdel(src)

/obj/structure/grille/Bumped(atom/user)
	if(ismob(user))
		shock(user, 70)


/obj/structure/grille/attack_paw(mob/user)
	attack_hand(user)

/obj/structure/grille/attack_hulk(mob/living/carbon/human/user, does_attack_animation = 0)
	if(user.a_intent == "harm")
		if(!shock(user, 70))
			..(user, 1)
		return 1

/obj/structure/grille/attack_hand(mob/living/user)
	user.changeNext_move(CLICK_CD_MELEE)
	user.do_attack_animation(src, ATTACK_EFFECT_KICK)
	user.visible_message("<span class='warning'>[user] hits [src].</span>", null, null, COMBAT_MESSAGE_RANGE, user)
	if(!shock(user, 70))
		take_damage(rand(5,10), BRUTE, "melee", 1)

/obj/structure/grille/attack_alien(mob/living/user)
	user.do_attack_animation(src)
	user.changeNext_move(CLICK_CD_MELEE)
	user.visible_message("<span class='warning'>[user] mangles [src].</span>", null, null, COMBAT_MESSAGE_RANGE, user)
	if(!shock(user, 70))
		take_damage(20, BRUTE, "melee", 1)


/obj/structure/grille/CanPass(atom/movable/mover, turf/target, height=0)
	if(height==0) return 1
	if(istype(mover) && mover.checkpass(PASSGRILLE))
		return 1
	else
		if(istype(mover, /obj/item/projectile) && density)
			return prob(30)
		else
			return !density

/obj/structure/grille/CanAStarPass(ID, dir, caller)
	. = !density
	if(ismovableatom(caller))
		var/atom/movable/mover = caller
		. = . || mover.checkpass(PASSGRILLE)

/obj/structure/grille/attackby(obj/item/weapon/W, mob/user, params)
	user.changeNext_move(CLICK_CD_MELEE)
	add_fingerprint(user)
	if(istype(W, /obj/item/weapon/wirecutters))
		if(!shock(user, 100))
			playsound(loc, W.usesound, 100, 1)
			deconstruct()
	else if((istype(W, /obj/item/weapon/screwdriver)) && (isturf(loc) || anchored))
		if(!shock(user, 90))
			playsound(loc, W.usesound, 100, 1)
			anchored = !anchored
			user.visible_message("<span class='notice'>[user] [anchored ? "fastens" : "unfastens"] [src].</span>", \
								 "<span class='notice'>You [anchored ? "fasten [src] to" : "unfasten [src] from"] the floor.</span>")
			return
	else if(istype(W, /obj/item/stack/rods) && broken)
		var/obj/item/stack/rods/R = W
		if(!shock(user, 90))
			user.visible_message("<span class='notice'>[user] rebuilds the broken grille.</span>", \
								 "<span class='notice'>You rebuild the broken grille.</span>")
			obj_integrity = max_integrity
			density = 1
			broken = 0
			icon_state = initial(icon_state)
			R.use(1)
			return

//window placing begin
	else if(istype(W, /obj/item/stack/sheet/rglass) || istype(W, /obj/item/stack/sheet/glass))
		if (!broken)
			var/obj/item/stack/ST = W
			if (ST.get_amount() < 2)
				user << "<span class='warning'>You need at least two sheets of glass for that!</span>"
				return
			var/dir_to_set = SOUTHWEST
			if(!anchored)
				user << "<span class='warning'>[src] needs to be fastened to the floor first!</span>"
				return
			for(var/obj/structure/window/WINDOW in loc)
				user << "<span class='warning'>There is already a window there!</span>"
				return
			user << "<span class='notice'>You start placing the window...</span>"
			if(do_after(user,20, target = src))
				if(!src.loc || !anchored) //Grille broken or unanchored while waiting
					return
				for(var/obj/structure/window/WINDOW in loc) //Another window already installed on grille
					return
				var/obj/structure/window/WD
				if(istype(W, /obj/item/stack/sheet/rglass))
					WD = new/obj/structure/window/reinforced/fulltile(loc) //reinforced window
				else
					WD = new/obj/structure/window/fulltile(loc) //normal window
				WD.setDir(dir_to_set)
				WD.ini_dir = dir_to_set
				WD.anchored = 0
				WD.state = 0
				ST.use(2)
				user << "<span class='notice'>You place [WD] on [src].</span>"
			return
//window placing end

	else if(istype(W, /obj/item/weapon/shard) || !shock(user, 70))
		return ..()

/obj/structure/grille/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	switch(damage_type)
		if(BRUTE)
			if(damage_amount)
				playsound(loc, 'sound/effects/grillehit.ogg', 80, 1)
			else
				playsound(loc, 'sound/weapons/tap.ogg', 50, 1)
		if(BURN)
			playsound(loc, 'sound/items/welder.ogg', 80, 1)


/obj/structure/grille/deconstruct(disassembled = TRUE)
	if(!loc) //if already qdel'd somehow, we do nothing
		return
	if(!(flags&NODECONSTRUCT))
		transfer_fingerprints_to(stored)
		var/turf/T = loc
		stored.forceMove(T)
	..()

/obj/structure/grille/obj_break()
	if(!broken && !(flags & NODECONSTRUCT))
		icon_state = "broken[initial(icon_state)]"
		density = 0
		broken = 1
		stored.amount = 1
		var/obj/item/stack/rods/newrods = new(loc)
		transfer_fingerprints_to(newrods)


// shock user with probability prb (if all connections & power are working)
// returns 1 if shocked, 0 otherwise

/obj/structure/grille/proc/shock(mob/user, prb)
	if(!anchored || broken)		// anchored/broken grilles are never connected
		return 0
	if(!prob(prb))
		return 0
	if(!in_range(src, user))//To prevent TK and mech users from getting shocked
		return 0
	var/turf/T = get_turf(src)
	var/obj/structure/cable/C = T.get_cable_node()
	if(C)
		if(electrocute_mob(user, C, src))
			var/datum/effect_system/spark_spread/s = new /datum/effect_system/spark_spread
			s.set_up(3, 1, src)
			s.start()
			return 1
		else
			return 0
	return 0

/obj/structure/grille/temperature_expose(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	if(!broken)
		if(exposed_temperature > T0C + 1500)
			take_damage(1, BURN, 0, 0)
	..()

/obj/structure/grille/hitby(AM as mob|obj)
	if(isobj(AM))
		if(prob(50) && anchored && !broken)
			var/turf/T = get_turf(src)
			var/obj/structure/cable/C = T.get_cable_node()
			if(C)
				playsound(src.loc, 'sound/magic/LightningShock.ogg', 100, 1, extrarange = 5)
				tesla_zap(src, 3, C.powernet.avail * 0.01) //Zap for 1/100 of the amount of power. At a million watts in the grid, it will be as powerful as a tesla revolver shot.
	return ..()

/obj/structure/grille/storage_contents_dump_act(obj/item/weapon/storage/src_object, mob/user)
	return 0

/obj/structure/grille/broken // Pre-broken grilles for map placement
	icon_state = "brokengrille"
	density = 0
	obj_integrity = 20
	broken = 1

/obj/structure/grille/broken/New()
	..()
	stored.amount = 1
	icon_state = "brokengrille"

/obj/structure/grille/ratvar
	icon_state = "ratvargrille"
	desc = "A strangely-shaped grille."

/obj/structure/grille/ratvar/New()
	..()
	change_construction_value(1)
	if(broken)
		PoolOrNew(/obj/effect/overlay/temp/ratvar/grille/broken, get_turf(src))
	else
		PoolOrNew(/obj/effect/overlay/temp/ratvar/grille, get_turf(src))
		PoolOrNew(/obj/effect/overlay/temp/ratvar/beam/grille, get_turf(src))

/obj/structure/grille/ratvar/Destroy()
	change_construction_value(-1)
	return ..()

/obj/structure/grille/ratvar/narsie_act()
	take_damage(rand(1, 3), BRUTE)
	if(src)
		var/previouscolor = color
		color = "#960000"
		animate(src, color = previouscolor, time = 8)

/obj/structure/grille/ratvar/ratvar_act()
	return

/obj/structure/grille/ratvar/broken
	density = 0
	obj_integrity = 20
	broken = 1

/obj/structure/grille/ratvar/broken/New()
	..()
	stored.amount = 1
	icon_state = "brokenratvargrille"
