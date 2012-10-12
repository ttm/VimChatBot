" Self-teaching chat bot (C) 2012 by Michael Kamensky, all rights reserved.
" This script is distributed under Vim license.
" =========================================================================

let s:ChatIteration = 1
let s:MagicalContexts = 2
let s:BotVersion = "1.1"

function! Random(min, max)
    if has("python")
	python from random import randint
	python from vim import command, eval
	python command("return %d" % randint(int(eval("a:min")), int(eval("a:max")))) 
    else
	let s:random_val = localtime() % 65536
	let s:random_val = (s:random_val * 31421 + 6927) % 65536
	let s:constrained_val = (s:random_val * a:max) / 65536 + a:min
	return s:constrained_val
    endif
endfunction

function! Macroexpand(phrase)
    let s:expanded_phrase = substitute(a:phrase, "\\$TIME\\$", strftime("%H:%M"), "g")
    let s:expanded_phrase = substitute(s:expanded_phrase, "\\$TIME12\\$", strftime("%I:%M %p"), "g")
    let s:expanded_phrase = substitute(s:expanded_phrase, "\\$WEEKDAY\\$", strftime("%A"), "g")
    let s:expanded_phrase = substitute(s:expanded_phrase, "\\$DAY\\$", strftime("%d"), "g")
    let s:expanded_phrase = substitute(s:expanded_phrase, "\\$MONTH\\$", strftime("%B"), "g")
    let s:expanded_phrase = substitute(s:expanded_phrase, "\\$YEAR\\$", strftime("%Y"), "g")
    return s:expanded_phrase
endfunction

function! GetLineMatchingPattern(pattern)
    let s:num_line = 1
    let s:max_line = line("$")
    while s:num_line != s:max_line
	if getline(s:num_line) =~ a:pattern
	    return s:num_line
	endif
	let s:num_line += 1
    endwhile
    return -1
endfunction

function! CountResponses(start_line)
    let s:num_responses = 0
    let s:cur_line = a:start_line + 1
    let s:max_line = line("$")
    if a:start_line <= 0
	return -1
    endif
    while s:cur_line < s:max_line
	if getline(s:cur_line) =~ "^\\s*$"
	    break
	endif
	let s:cur_line += 1
	let s:num_responses += 1
    endwhile
    return s:num_responses
endfunction

function! HasResponse(start_line, resp)
    let s:has_response = 0
    let s:cur_line = a:start_line + 1
    let s:max_line = line("$")
    if a:start_line <= 0
	return -1
    endif
    while s:cur_line < s:max_line
	if getline(s:cur_line) =~ a:resp
	    let s:has_response = 1
	    break
	elseif getline(s:cur_line) =~ "^\\s*$"
	    break
	endif
	let s:cur_line += 1
    endwhile
    return s:has_response
endfunction

function! AI_AddResponse(pattern, new_resp, iteration)
    let s:signature = ":::"
    if a:iteration <= s:MagicalContexts
	let s:signature = s:signature . a:iteration
    endif
    let s:resp_block = GetLineMatchingPattern(a:pattern . s:signature)
    if s:resp_block == -1
	call AI_Store_New_Response(a:pattern, a:new_resp, a:iteration)
	return 0
    endif
    let s:has_resp = HasResponse(s:resp_block, a:new_resp)
    if s:has_resp == 1
	return -1
    endif
    execute ("normal " . s:resp_block . "gg")
    execute ("normal o" . a:new_resp)
    return 0
endfunction

function! AI_Decide_Response(pattern)
    let s:resp_block = GetLineMatchingPattern(a:pattern)
    if s:resp_block == -1
	return -1
    endif
    let s:has_resp = HasResponse(s:resp_block, a:pattern)
    if s:has_resp == -1
	return -1
    endif
    let s:num_responses = CountResponses(s:resp_block)
    return s:resp_block + Random(1, s:num_responses)
endfunction

function! AI_Store_New_Response(pattern, response, iteration)
    execute ("normal Go")
    if a:iteration <= s:MagicalContexts
	execute ("normal o" . a:pattern . ":::" . a:iteration)
    else
	execute ("normal o" . a:pattern . ":::")
    endif
    execute ("normal o" . a:response)
    execute ("normal o")
endfunction

function! AI_Respond(pattern, iteration) 
    if a:iteration <= s:MagicalContexts
	let s:chosen_response = AI_Decide_Response("^" . a:pattern . ":::" . a:iteration . "$")
	let s:resp_offset = 5
	let s:request_group = 'v:val =~ ".*:::' . a:iteration . '$"'
	let s:request_signature = ":::" . a:iteration
	if a:iteration == s:MagicalContexts
	    let s:next_request = 'v:val =~ ".*:::$"'
	    let s:resp_offset = 4
	    let s:request_group = 'v:val =~ ".*:::' . a:iteration . '$"'
	    let s:request_signature = ":::" . a:iteration
	else
	    let s:next_request = 'v:val =~ ".*:::' . (a:iteration + 1) . '$"'
	endif
    else
	let s:chosen_response = AI_Decide_Response("^" . a:pattern . ":::$")
	let s:resp_offset = 4
	let s:request_group = 'v:val =~ ".*:::$"'
	let s:next_request = 'v:val =~ ".*:::$"'
	let s:request_signature = ":::"
    endif
    if s:chosen_response != -1
	echo "ChatBot: " . Macroexpand(getline(s:chosen_response)) . "\n"
    else
	echohl Comment
	echo "ChatBot: I don't understand that. Can you please teach me what to say?\n"
	echohl None
	let s:suggested_response = input("You say: ")
	if s:suggested_response == "/Q" || s:suggested_response =~ "^\\s*$"
	    echohl Comment
	    echo "ChatBot: Fine, don't teach me if you don't want to!\n"
	    echohl N
	    return
	endif
	echo "Human: " . Macroexpand(s:suggested_response) . "\n"
	call AI_Store_New_Response(a:pattern, s:suggested_response, a:iteration)
	echohl Comment
	echo "ChatBot: Thanks, I'll remember that!\n"
	echohl None
    endif
    let s:decide_to_ask_back = Random(0, 1)
    if s:decide_to_ask_back
	let s:lines = getline(1, line("$"))
	let s:requests = filter(s:lines, s:next_request)
	if len(s:requests) != 0
	    let s:decision = Random(0, len(s:requests) - 1)
	    echo "ChatBot: " . Macroexpand(s:requests[s:decision][:-s:resp_offset]) . "\n"
	    let s:taught_response = input("You say: ")
	    if s:taught_response == "/Q" || s:taught_response =~ "^\\s*$"
		echohl Comment
		echo "ChatBot: Fine, don't want to answer me - don't answer.\n"
		echohl None
		return
	    endif
	    echo "Human: " . Macroexpand(s:taught_response) . "\n"
	    let s:response_group_loc = GetLineMatchingPattern(s:requests[s:decision][:-s:resp_offset] . s:request_signature)
	    let s:already_has_resp = HasResponse(s:response_group_loc, s:taught_response)
	    if s:already_has_resp != 1
		call AI_AddResponse(s:requests[s:decision][:-s:resp_offset], s:taught_response, a:iteration)
		echohl Comment
		echo "ChatBot: Oh, thanks, that's a good way to respond to that! I'll remember it!\n"
		echohl None
	    endif
	endif
    endif
endfunction

function! MainChatLoop()
    let s:ChatIteration = 1
    let s:more_status = &more
    setlocal nomore
    echohl Comment
    echo "Welcome to Agetian's ChatBot for Vim v" . s:BotVersion . "! Enjoy and have fun!\n"
    echo "Type /Q to choose not to answer the bot's question or to end the conversation.\n"
    echohl None
    while 1
	let s:HumanResponse = input("You say: ")
	if s:HumanResponse =~ "^\\s*$"
	    continue
	endif
	if s:HumanResponse == "/Q"
	    echo "ChatBot: Bye-bye!\n"
	    break
	endif
	echo "Human: " . Macroexpand(s:HumanResponse) . "\n"
	call AI_Respond(s:HumanResponse, s:ChatIteration)
	let s:ChatIteration += 1
    endwhile
    let &more = s:more_status
endfunction

nnoremap <silent> \Cb :call MainChatLoop()<CR>
finish

------> HERE-DOCUMENT WITH THE CHAT BOT DATABASE BEGINS HERE <------


Hi!:::1
Hi!

How's it going?:::2
I'm doing good, thanks!

What's new?:::
Not a whole lot!
Not much!

How's it going?:::1
Doing good, thanks!
Good, thanks!

Are you a robot?:::2
No, I'm an alien!
No, of course not!

What are you doing?:::
Nothing special.
Talking to a robot.
Talking to you!

Are you a robot?:::1
No...
No

What about you?:::
Same! 
Doing good, thanks!

Are you a robot?:::
No, of course not!

Should I work today?:::
No, you shouldn't.
Probably :P
Yes, of course!
I don't know, to be honest.

What's new?:::2
Not a whole lot!

What's new?:::1
Not much, what about you?
Not much!

What are you doing?:::2
Talking to you!

Are you an alien?:::
No.
Yes, sure!
Yes, yes I am.
You could say so.

What about you?:::2
Doing good!
I'm great, thanks!


What time is it?:::
It's $TIME$.


What day of the week is it?:::
It's $WEEKDAY$!

