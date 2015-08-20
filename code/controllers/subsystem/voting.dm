var/datum/subsystem/vote/SSvote

/datum/subsystem/vote
	name = "Vote"
	can_fire = 1
	wait = 10
	priority = -1

	var/initiator = null
	var/started_time = null
	var/time_remaining = 0
	var/mode = null
	var/question = null
	var/list/choices = list()
	var/list/voted = list()
	var/list/voting = list()

/datum/subsystem/vote/New()
	NEW_SS_GLOBAL(SSvote)

/datum/subsystem/vote/fire()	//called by master_controller
	if(mode)
		time_remaining = round((started_time + config.vote_period - world.time)/10)

		if(time_remaining < 0)
			result()
			for(var/client/C in voting)
				C << browse(null, "window=vote;can_close=0")
			reset()
		else
			var/datum/browser/client_popup
			for(var/client/C in voting)
				client_popup = new(C, "vote", "Voting Panel")
				client_popup.set_window_options("can_close=0")
				client_popup.set_content(interface(C))
				client_popup.open(0)


/datum/subsystem/vote/proc/reset()
	initiator = null
	time_remaining = 0
	mode = null
	question = null
	choices.Cut()
	voted.Cut()
	voting.Cut()

/datum/subsystem/vote/proc/get_result()
	//get the highest number of votes
	var/greatest_votes = 0
	var/total_votes = 0
	for(var/option in choices)
		var/votes = choices[option]
		total_votes += votes
		if(votes > greatest_votes)
			greatest_votes = votes
	//default-vote for everyone who didn't vote
	if(!config.vote_no_default && choices.len)
		var/non_voters = (clients.len - total_votes)
		if(non_voters > 0)
			if(mode == "restart")
				choices["Continue Playing"] += non_voters
				if(choices["Continue Playing"] >= greatest_votes)
					greatest_votes = choices["Continue Playing"]
			else if(mode == "gamemode")
				if(master_mode in choices)
					choices[master_mode] += non_voters
					if(choices[master_mode] >= greatest_votes)
						greatest_votes = choices[master_mode]
	//get all options with that many votes and return them in a list
	. = list()
	if(greatest_votes)
		for(var/option in choices)
			if(choices[option] == greatest_votes)
				. += option
	return .

/datum/subsystem/vote/proc/announce_result()
	var/list/winners = get_result()
	var/text
	if(winners.len > 0)
		if(question)
			question = copytext(sanitize_u2a(question), 1, MAX_MESSAGE_LEN)
			text += "<b>[question]</b>"
			question = copytext(sanitize_a2u(question), 1, MAX_MESSAGE_LEN)
		else			text += "<b>[capitalize(mode)] Vote</b>"
		for(var/i=1,i<=choices.len,i++)
			var/votes = choices[choices[i]]
			if(!votes)	votes = 0
			choices[i] = copytext(sanitize_u2a(choices[i]), 1, MAX_MESSAGE_LEN)
			text += "\n<b>[choices[i]]:</b> [votes]"
		if(mode != "custom")
			if(winners.len > 1)
				text = "\n<b>Vote Tied Between:</b>"
				for(var/option in winners)
					option = copytext(sanitize_u2a(option), 1, MAX_MESSAGE_LEN)
					text += "\n\t[option]"
			. = pick(winners)
			text += "\n<b>Vote Result: [.]</b>"
		else
			text += "\n<b>Did not vote:</b> [clients.len-voted.len]"
	else
		text += "<b>Vote Result: Inconclusive - No Votes!</b>"
	log_vote(text)
	world << "\n<font color='purple'>[text]</font>"
	return .

/datum/subsystem/vote/proc/result()
	. = announce_result()
	var/restart = 0
	if(.)
		switch(mode)
			if("restart")
				if(. == "Restart Round")
					restart = 1
			if("gamemode")
				if(master_mode != .)
					world.save_mode(.)
					if(ticker && ticker.mode)
						restart = 1
					else
						master_mode = .
			if("ooc")
				if(. == "�������� OOC")
					ooc_allowed = 1
					world << "<B>The OOC channel has been globally enabled!</B>"
				if(. == "��������� OOC")
					ooc_allowed = 0
					world << "<B>The OOC channel has been globally disabled!</B>"
			if("looc")
				if(. == "�������� LOOC")
					looc_allowed = 1
					world << "<B>The LOOC channel has been globally enabled!</B>"
				if(. == "��������� LOOC")
					looc_allowed = 0
					world << "<B>The LOOC channel has been globally disabled!</B>"

	if(restart)
		var/active_admins = 0
		for(var/client/C in admins)
			if(!C.is_afk() && check_rights_for(C, R_SERVER))
				active_admins = 1
				break
		if(!active_admins)
			world.Reboot("Restart vote successful.", "end_error", "restart vote")
		else
			world << "<span style='boldannounce'>Notice:Restart vote will not restart the server automatically because there are active admins on.</span>"
			message_admins("A restart vote has passed, but there are active admins on with +server, so it has been canceled. If you wish, you may restart the server.")

	return .

/datum/subsystem/vote/proc/submit_vote(vote)
	if(mode)
		if(config.vote_no_dead && usr.stat == DEAD && !usr.client.holder)
			return 0
		if(!(usr.ckey in voted))
			if(vote && 1<=vote && vote<=choices.len)
				voted += usr.ckey
				choices[choices[vote]]++	//check this
				return vote
	return 0

/datum/subsystem/vote/proc/initiate_vote(vote_type, initiator_key)
	if(!mode)
		if(started_time != null)
			var/next_allowed_time = (started_time + config.vote_delay)
			if(next_allowed_time > world.time)
				return 0

		reset()
		switch(vote_type)
			if("restart")	choices.Add("Restart Round","Continue Playing")
			if("gamemode")	choices.Add(config.votable_modes)
			if("ooc")	choices.Add("�������� OOC", "��������� OOC")
			if("looc")	choices.Add("�������� LOOC", "��������� LOOC")
			if("custom")
				question = stripped_input(usr,"What is the vote for?")
				question = copytext(sanitize_u(question), 1, MAX_MESSAGE_LEN)
				if(!question)	return 0
				for(var/i=1,i<=10,i++)
					var/option = capitalize(stripped_input(usr,"Please enter an option or hit cancel to finish"))
					option = copytext(sanitize_u(option), 1, MAX_MESSAGE_LEN)
					if(!option || mode || !usr.client)	break
					choices.Add(option)
			else			return 0
		mode = vote_type
		initiator = initiator_key
		started_time = world.time
		var/text = "[capitalize(mode)] vote started by [initiator]."
		if(mode == "custom")
			question = copytext(sanitize_u2a(question), 1, MAX_MESSAGE_LEN)
			text += "\n[question]"
			question = copytext(sanitize_a2u(question), 1, MAX_MESSAGE_LEN)
		log_vote(text)
		world << "\n<font color='purple'><b>[text]</b>\nType <b>vote</b> or click <a href='?src=\ref[src]'>here</a> to place your votes.\nYou have [config.vote_period/10] seconds to vote.</font>"
		time_remaining = round(config.vote_period/10)
		return 1
	return 0

/datum/subsystem/vote/proc/interface(client/C)
	if(!C)	return
	var/admin = 0
	var/trialmin = 0
	if(C.holder)
		admin = 1
		if(check_rights_for(C, R_ADMIN))
			trialmin = 1
	voting |= C

	if(mode)
		if(question)	. += "<h2>Vote: '[question]'</h2>"
		else			. += "<h2>Vote: [capitalize(mode)]</h2>"
		. += "Time Left: [time_remaining] s<hr><ul>"
		for(var/i=1,i<=choices.len,i++)
			var/votes = choices[choices[i]]
			if(!votes)	votes = 0
			. += "<li><a href='?src=\ref[src];vote=[i]'>[choices[i]]</a> ([votes] votes)</li>"
		. += "</ul><hr>"
		if(admin)
			. += "(<a href='?src=\ref[src];vote=cancel'>Cancel Vote</a>) "
	else
		. += "<h2>Start a vote:</h2><hr><ul><li>"
		//restart
		if(trialmin || config.allow_vote_restart)
			. += "<a href='?src=\ref[src];vote=restart'>Restart</a>"
		else
			. += "<font color='grey'>Restart (Disallowed)</font>"
		if(trialmin)
			. += "\t(<a href='?src=\ref[src];vote=toggle_restart'>[config.allow_vote_restart?"Allowed":"Disallowed"]</a>)"
		. += "</li><li>"
		//gamemode
		if(trialmin || config.allow_vote_mode)
			. += "<a href='?src=\ref[src];vote=gamemode'>GameMode</a>"
		else
			. += "<font color='grey'>GameMode (Disallowed)</font>"
		if(trialmin)
			. += "\t(<a href='?src=\ref[src];vote=toggle_gamemode'>[config.allow_vote_mode?"Allowed":"Disallowed"]</a>)"

		. += "</li>"
		//ooc
		. += "<li><a href='?src=\ref[src];vote=ooc'>Toggle OOC</a></li>"
		//looc
		. += "<li><a href='?src=\ref[src];vote=looc'>Toggle LOOC</a></li>"
		//custom
		if(trialmin)
			. += "<li><a href='?src=\ref[src];vote=custom'>Custom</a></li>"

		. += "</ul><hr>"
	. += "<a href='?src=\ref[src];vote=close' style='position:absolute;right:50px'>Close</a>"
	return .


/datum/subsystem/vote/Topic(href,href_list[],hsrc)
	if(!usr || !usr.client)	return	//not necessary but meh...just in-case somebody does something stupid
	switch(href_list["vote"])
		if("close")
			voting -= usr.client
			usr << browse(null, "window=vote")
			return
		if("cancel")
			if(usr.client.holder)
				reset()
		if("toggle_restart")
			if(usr.client.holder)
				config.allow_vote_restart = !config.allow_vote_restart
		if("toggle_gamemode")
			if(usr.client.holder)
				config.allow_vote_mode = !config.allow_vote_mode
		if("restart")
			if(config.allow_vote_restart || usr.client.holder)
				initiate_vote("restart",usr.key)
		if("gamemode")
			if(config.allow_vote_mode || usr.client.holder)
				initiate_vote("gamemode",usr.key)
		if("ooc")
			initiate_vote("ooc",usr.key)
		if("looc")
			initiate_vote("looc",usr.key)
		if("custom")
			if(usr.client.holder)
				initiate_vote("custom",usr.key)
		else
			submit_vote(round(text2num(href_list["vote"])))
	usr.vote()


/mob/verb/vote()
	set category = "OOC"
	set name = "Vote"

	var/datum/browser/popup = new(src, "vote", "Voting Panel")
	popup.set_window_options("can_close=0")
	popup.set_content(SSvote.interface(client))
	popup.open(0)

