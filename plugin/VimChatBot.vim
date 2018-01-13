" VimChatBot.vim    : A self-teaching chat bot for Vim 
" Version           : 1.9
" Maintainer        : Michael Kamensky <stavdev@mail.ru>
" Last Modified     : 04/11/2014
" License           : This script is released under the Vim License.
" ============================================================================
" Usage             : By default, the chat bot is mapped to <Leader>Cb
"                   :
"                   : Only initiate the conversation when a chat bot database
"                   : is open in the current buffer (or a new file if you
"                   : don't yet have a chat database, or this script file if
"                   : you'd like to use the here-document part of this script
"                   : for the chat database). The reason for this is that the
"                   : chat bot will automatically add new lines to the current
"                   : buffer as it learns new phrases from the human, thus
"                   : creating and updating its database of known phrases.
"                   : 
"                   : Type /Q to finish the conversation (unless the bot is
"                   : in the middle of asking you something). If the bot is
"                   : asking you something, /Q aborts the question without
"                   : a reply. In that case, typing /Q the second time quits
"                   : the conversation.
"                   :
"                   : Ctrl+C can be used to forcefully finish the conversation
"                   : without having to type /Q once or twice.

if v:version < 704
  echohl Error
  echo "ERROR: Vim v7.4 or newer is required for Vim ChatBot!"
  echohl None
  finish
endif

" if exists("g:loaded_VimChatBot")
"   finish
" endif

let g:loaded_VimChatBot = 1

" Chat initiation mapping, default <Leader>Cb
nnoremap <Leader>Cb :call VCB_MainChatLoop()<CR>

" Script variables
let s:ChatIteration = 1
let s:MagicalContexts = 2
let s:BotVersion = "1.9"

" Vi compatibility mode workaround
let s:GlobalCPO = &cpo
setlocal cpo&vim

function! s:VCB_Random(min, max) " {{{
  if has("python3")
    python3 from random import randint
    python3 from vim import command, eval
    python3 command("return %d" % randint(int(eval("a:min")), int(eval("a:max")))) 
  else
    let random_val = localtime() % 65536
    let random_val = (random_val * 31421 + 6927) % 65536
    let constrained_val = (random_val * a:max) / 65536 + a:min
    return constrained_val
  endif
endfunction " }}}

function! Randint(min, max) " {{{
  if has("python3")
    python3 from random import randint
    python3 from vim import command, eval
    python3 command("return %d" % randint(int(eval("a:min")), int(eval("a:max")))) 
  else
    let random_val = localtime() % 65536
    let random_val = (random_val * 31421 + 6927) % 65536
    let constrained_val = (random_val * a:max) / 65536 + a:min
    return constrained_val
  endif
endfunction " }}}

function! s:VCB_Macroexpand(phrase) " {{{
  echom 'phrase' a:phrase
  let expanded_phrase = substitute(a:phrase, "\\$TIME\\$", strftime("%H:%M"), "g")
  let expanded_phrase = substitute(expanded_phrase, "\\$TIME12\\$", strftime("%I:%M %p"), "g")
  let expanded_phrase = substitute(expanded_phrase, "\\$WEEKDAY\\$", strftime("%A"), "g")
  let expanded_phrase = substitute(expanded_phrase, "\\$DAY\\$", strftime("%d"), "g")
  let expanded_phrase = substitute(expanded_phrase, "\\$MONTH\\$", strftime("%B"), "g")
  let expanded_phrase = substitute(expanded_phrase, "\\$YEAR\\$", strftime("%Y"), "g")
  let expanded_phrase = substitute(expanded_phrase, "\\$HOUR\\$", strftime("%H"), "g")
  let expanded_phrase = substitute(expanded_phrase, "\\$MINUTE\\$", strftime("%M"), "g")
  let expanded_phrase = substitute(expanded_phrase, "\\$SECOND\\$", strftime("%S"), "g")
  let expanded_phrase = substitute(expanded_phrase, "\\$SECONDD\\$", strftime("%S") . 'YIUUIYIU', "g")
  let expanded_phrase = substitute(expanded_phrase, "\\$AABCD\\$", string(g:aa_status), "g")
  return expanded_phrase
endfunction " }}}

function! s:VCB_GetLineMatchingPattern(pattern) " {{{
  let num_line = 1
  let max_line = line("$")
  while num_line != max_line
    if getline(num_line) =~ a:pattern
      return num_line
    endif
    let num_line += 1
  endwhile
  return -1
endfunction " }}}

function! s:VCB_CountResponses(start_line) " {{{
  let num_responses = 0
  let cur_line = a:start_line + 1
  let max_line = line("$")
  if a:start_line <= 0
    return -1
  endif
  while cur_line < max_line
    if getline(cur_line) =~ "^\\s*$"
      break
    endif
    let cur_line += 1
    let num_responses += 1
  endwhile
  return num_responses
endfunction " }}}

function! s:VCB_HasResponse(start_line, resp) " {{{
  let has_response = 0
  let cur_line = a:start_line + 1
  let max_line = line("$")
  if a:start_line <= 0
    return -1
  endif
  while cur_line < max_line
    if getline(cur_line) =~ a:resp
      let has_response = 1
      break
    elseif getline(cur_line) =~ "^\\s*$"
      break
    endif
    let cur_line += 1
  endwhile
  return has_response
endfunction " }}}

function! s:VCB_AI_AddResponse(pattern, new_resp, iteration) " {{{
  let signature = ":::"
  if a:iteration <= s:MagicalContexts
    let signature = signature . a:iteration
  endif
  let resp_block = s:VCB_GetLineMatchingPattern(a:pattern . signature)
  if resp_block == -1
    call s:VCB_AI_Store_New_Response(a:pattern, a:new_resp, a:iteration)
    return 0
  endif
  let has_resp = s:VCB_HasResponse(resp_block, a:new_resp)
  if has_resp == 1
    return -1
  endif
  execute ("normal " . resp_block . "gg")
  execute ("normal o" . a:new_resp)
  return 0
endfunction " }}}

function! s:VCB_AI_Decide_Response(pattern) " {{{
  let resp_block = s:VCB_GetLineMatchingPattern(a:pattern)
  if resp_block == -1
    return -1
  endif
  let has_resp = s:VCB_HasResponse(resp_block, a:pattern)
  if has_resp == -1
    return -1
  endif
  let num_responses = s:VCB_CountResponses(resp_block)
  return resp_block + s:VCB_Random(1, num_responses)
endfunction " }}}

function! s:VCB_AI_Store_New_Response(pattern, response, iteration) " {{{
  " execute ("normal Go")
  " if a:iteration <= s:MagicalContexts
  "   execute ("normal o" . a:pattern . ":::" . a:iteration)
  " else
  "   execute ("normal o" . a:pattern . ":::")
  " endif
  " execute ("normal o" . a:response)
  " execute ("normal o")
  execute "!cat '" . a:pattern .":::' >> " . expand("%:p")
  execute "!cat '\n" . a:response ."' >> " . expand("%:p")
endfunction " }}}

function! s:VCB_AI_Respond(pattern, iteration)  " {{{
  if a:iteration <= s:MagicalContexts
    let chosen_response = s:VCB_AI_Decide_Response("^" . a:pattern . ":::" . a:iteration . "$")
    let resp_offset = 5
    let request_group = 'v:val =~ ".*:::' . a:iteration . '$"'
    let request_signature = ":::" . a:iteration
    if a:iteration == s:MagicalContexts
      let next_request = 'v:val =~ ".*:::$"'
      let resp_offset = 4
      let request_group = 'v:val =~ ".*:::' . a:iteration . '$"'
      let request_signature = ":::" . a:iteration
    else
      let next_request = 'v:val =~ ".*:::' . (a:iteration + 1) . '$"'
    endif
  else
    let chosen_response = s:VCB_AI_Decide_Response("^" . a:pattern . ":::$")
    let resp_offset = 4
    let request_group = 'v:val =~ ".*:::$"'
    let next_request = 'v:val =~ ".*:::$"'
    let request_signature = ":::"
  endif
  echo 'chosen response' chosen_response
  if chosen_response != -1
    echo "ChatBot: " . s:VCB_Macroexpand(getline(chosen_response)) . "\n"
  else
    echohl Comment
    echo "ChatBot: I don't understand that. Can you please tell me what you would say?\n"
    echohl None
    let suggested_response = input("You say: ")
    echo "\n"
    if suggested_response == "/Q" || suggested_response =~ "^\\s*$"
      echohl Comment
      echo "ChatBot: Fine, don't teach me if you don't want to!\n"
      echohl None
      return
    endif
    call s:VCB_AI_Store_New_Response(a:pattern, suggested_response, a:iteration)
    echohl Comment
    echo "ChatBot: Thanks, I'll remember that!\n"
    echohl None
  endif
  let decide_to_ask_back = s:VCB_Random(0, 1)
  if decide_to_ask_back
    call s:VCB_AI_AskBack(resp_offset, a:iteration + 1, next_request, request_signature)
  endif
endfunction " }}}

function! s:VCB_AI_AskBack(resp_offset, iteration, next_request, request_signature) " {{{
  let lines = getline(1, line("$"))
  let requests = filter(lines, a:next_request)
  if len(requests) != 0
    let decision = s:VCB_Random(0, len(requests) - 1)
    echo 'decision' decision
    echo "ChatBot: " . s:VCB_Macroexpand(requests[decision][:-a:resp_offset]) . "\n"
    let taught_response = input("You say: ")
    echo "\n"
    if taught_response == "/Q" || taught_response =~ "^\\s*$"
      echohl Comment
      echo "ChatBot: Fine, don't want to answer me - don't answer.\n"
      echohl None
      return
    endif
    let response_group_loc = s:VCB_GetLineMatchingPattern(requests[decision][:-a:resp_offset] . a:request_signature)
    let already_has_resp = s:VCB_HasResponse(response_group_loc, taught_response)
    if already_has_resp != 1
      call s:VCB_AI_AddResponse(requests[decision][:-a:resp_offset], taught_response, a:iteration)
      echohl Comment
      echo "ChatBot: Oh, thanks, that's a good way to respond to that! I'll remember it!\n"
      echohl None
    endif
    return 1
  endif
  return 0
endfunction " }}}

function! VCB_MainChatLoop() " {{{
  let s:ChatIteration = 1
  let more_status = &more
  let cpo_status = &cpo
  let case_status = &ignorecase
  setlocal nomore
  setlocal cpo&vim
  setlocal ignorecase
  echohl Comment
  echo "Welcome to Agetian's ChatBot for Vim v" . s:BotVersion . "! Enjoy and have fun!\n"
  echo "Type /Q to choose not to answer the bot's question or to end the conversation.\n"
  echohl None
  while 1
    if s:ChatIteration == 1
      let speak_first = s:VCB_Random(0, 1)
      if speak_first
        let spoken_first = s:VCB_AI_AskBack(5, 1, 'v:val =~ ".*:::1$"', ":::1")
        if spoken_first == 1
          let s:ChatIteration += 1
        endif
      endif
    endif
    let HumanResponse = input("You say: ")
    echo "\n"
    if HumanResponse =~ "^\\s*$"
      continue
    endif
    if HumanResponse == "/Q"
      echo "ChatBot: Bye-bye!\n"
      break
    endif
    call s:VCB_AI_Respond(HumanResponse, s:ChatIteration)
    let s:ChatIteration += 1
  endwhile
  let &more = more_status
  let &cpo = cpo_status
  let &ignorecase = case_status
endfunction " }}}

let &cpo = s:GlobalCPO
finish

------> HERE-DOCUMENT WITH THE CHAT BOT DATABASE BEGINS HERE <------


Hi!:::1
AA
Hi!

How's it going?:::2
I'm doing good, thanks!
Pretty good!
Good!
Doing good, thanks!
Good, thanks!


What's new?:::
Nothing.
Not a whole lot!
Not much!

Are you a robot?:::2
No, I'm an alien!
No, of course not!

What are you doing?:::
Nothing special.
Talking to a robot.
Talking to you!

Are you a robot?:::
No, of course not!

Should I work today?:::
I think so.
I guess so.
No, you shouldn't.
Probably :P
Yes, of course!
I don't know, to be honest.

What's new?:::2
Not much!
Not a whole lot!

Are you an alien?:::
No.
Yes, sure!
Yes, yes I am.
You could say so.


What time is it?:::
8am
It's $TIME$.


What day of the week is it?:::
It's $WEEKDAY$!


What year is it?:::
2018
It's $YEAR$.

SS:::1
AA
It's $SECONDD$.
SS:::2
It's $SECONDD$.
SS:::
It's $SECONDD$.

AA:::
It's $AABCD$.


AA:::1
AA
dsaidjis


AA:::2
asoidjjs


What year is it?:::1
asd


What year is it?:::2
qwe


A:::
AA


Hi!:::2
saudi


Hi!:::
b

