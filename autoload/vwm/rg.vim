
let s:job_started = 0

fun! vwm#rg#open(pattern, opt)
    if !executable('rg')
        echoerr 'rg is not executable'
        return
    endif

    let opt = a:opt
    let cmd = ['rg', '--column', '--trim', '--color', 'never']

    let glob_flag = has('win32') ? '--iglob' : '-g'
    if len(get(opt, 'include', ''))
        let include = vwm#rg#to_glob(opt.include)
        let cmd += [glob_flag, include]
    endif
    if len(get(opt, 'exclude', ''))
        let exclude = vwm#rg#to_glob(opt.exclude)
        let cmd += [glob_flag, '!' . exclude]
    endif

    if get(opt, 'word')
        let cmd += ['-w']
    endif

    if has_key(opt, 'case')
        let cmd += [opt.case ? '-s' : '-i']
    else
        let cmd += ['-S']
    endif

    if get(opt, 'regex')
        let cmd +=  ['-e', a:pattern]
    else
        let cmd +=  [a:pattern]
    endif

    let cmd += ['.']

    call vwm#open_left_panel()
    call vwm#rg#result_buffer()

    call vwm#rg#cancel()
    let s:job_id = jobstart(cmd, {
        \ 'on_stdout': 'vwm#rg#on_data',
        \ 'on_exit': 'vwm#rg#on_exit',
        \ 'pty': 1, 'width': 1000
    \ })
    let s:job_started = 1

    let g:rg_file_count = 0
    let g:rg_result_count = 0
    call nvim_buf_set_lines(s:rg_buf, 0, 1, 0, ['Searching ...'])

    call setqflist([])
endf

fun! vwm#rg#result_buffer()
    let b = get(s:, 'rg_buf')
    if b && bufexists(b)
        call nvim_buf_set_lines(s:rg_buf, 0, -1, 0, [])
        exec b 'b'
    else
        noau e rg://search_result
        let s:rg_buf = bufnr('%')

        setl nonu nowrap bt=nofile signcolumn=no nolist fcs=
        setl foldexpr=vwm#rg#fold_expr()
        setl conceallevel=2 concealcursor=niv
        " setl fdm=manual
        setl fdm=expr fdl=2
        setl foldtext='+\ '.getline(v:foldstart)
        setf vwm_rg_search

        syntax match ModeMsg /\v^\S.*$/
        syntax match RGLineCol /\v^\s+#\S+/ contains=RgQfIdx
        syntax match Type    /\v\%1l^Done.*/
        syntax match RgQfIdx /\v^\s+\zs#\d+:/ containedin=RGLineCol conceal

        hi link RGLineCol Comment

        nnore <buffer><silent><tab> :let &fdl = &fdl ? 0 : 2<cr>
        nnore <buffer><silent>o     <nop>
        nnore <buffer><silent>q     :call vwm#rg#cancel()<cr>
        nnore <buffer><silent><cr>  :call vwm#rg#current('open')<cr>
        nmap <buffer><silent><2-LeftMouse>  <cr>
        nmap <buffer><silent><RightMouse>  <cr>
    endif
endf

fun! vwm#rg#fold_expr()
    let text = getline(v:lnum)
    return v:lnum < 3 ? 0 : text =~ '^\S' ? 1 : empty(text) ? '<1' : '='
endf

fun! vwm#rg#current(action)
    let l = getline('.')
    let qf_idx = matchstr(l, '\v^\s+#\zs\d+')
    if len(qf_idx)
        call vwm#goto_normal_window()
        exec 'cc' qf_idx
    elseif filereadable(l)
        call vwm#goto_normal_window()
        exec 'drop' l
    endif
endf

fun! vwm#rg#on_data(j, d, e)
    let lines = []
    for d in a:d
        " 过滤掉控制字符
        let d = substitute(d, '\e.*', '', '')
        let d = substitute(d, '\r*\n*$', '', '')

        " 提取行列，添加到quickfix
        let m = matchlist(d, '\v^(\d+):(\d+):\s*(.*)')
        if len(m)
            let [l, c, data] = m[1:3]
            let g:rg_result_count += 1
            call setqflist([{'filename': s:curfile, 'lnum': l, 'col': c, 'text': data}], 'a')
            let spaces = 8 - len(l) - len(c)
            let spaces = spaces < 1 ? 1 : spaces
            let d = printf(" #%d:%d:%d", g:rg_result_count, l, c) . repeat(' ', spaces) . data
        elseif empty(d)
            " 判断文件结尾，创建折叠
            continue
        else
            " 判断文件名，保存文件名、所在行号
            " let d = substitute(d, '\v^\.[/\\]', '', '')
            let d = fnamemodify(d, ':.')
            let s:curfile = d
            let ln = nvim_buf_line_count(s:rg_buf)
            let g:rg_file_count += 1
            call add(lines, '')
        endif

        call add(lines, d)
    endfor

    if len(lines)
        call nvim_buf_set_lines(s:rg_buf, -1, -1, 0, lines)
    endif
endf

fun! vwm#rg#on_exit(j, d, e)
    if !s:job_started | return | endif
    let text = 'Done: ' . s:result_string() . ' Exit: ' . a:d
    call nvim_buf_set_lines(s:rg_buf, 0, 1, 0, [text])
    call vwm#goto_normal_window()
    sil! crewind
    let s:job_started = 0
endf

fun! s:result_string()
    return g:rg_result_count . ' results in ' . g:rg_file_count . ' files.'
endf

" 将逗号分隔的形式转换成glob语法
fun! vwm#rg#to_glob(text)
    let t = a:text
    let t = substitute(t, '\\', '/', 'g')
    if match(t, ',') > 0
        return '{' . t . '}'
    endif
    return t
endf

let g:rg_opt = {
    \ 'word': 0, 'text': '',
    \ 'include': get(g:, 'vwm#rg#include', ''),
    \ 'exclude': get(g:, 'vwm#rg#exclude', ''),
\ }
let g:rg_uibuf = -1

fun! vwm#rg#ui(pattern, opt)
    let width = 64
    call nvim_open_win(bufnr('%'), 1, {
        \ 'relative': 'editor',
        \ 'height': 8, 'width': width,
        \ 'row': 2, 'col': (&columns-width)/3,
    \ })

    let g:rg_opt.text = len(a:pattern) ? a:pattern : g:rg_opt.text
    call extend(g:rg_opt, a:opt)

    call vwm#rg#ui_buf()
endf

fun! vwm#rg#ui_buf()
    if bufexists(g:rg_uibuf)
        exec g:rg_uibuf 'b!'
    else
        ene!
        let g:rg_uibuf = bufnr('%')

        ino <buffer><silent><m-r> <c-r>=vwm#ui#toggle_checkbox('regex')<cr>
        ino <buffer><silent><m-w> <c-r>=vwm#ui#toggle_checkbox('word')<cr>
        ino <buffer><silent><m-c> <c-r>=vwm#ui#toggle_checkbox('case')<cr>
        ino <buffer><silent><cr>  <esc>:call vwm#rg#build()<cr>
        ino <buffer><silent><esc> <esc>:close<cr>
        nno <buffer><silent><esc> :close<cr>

        call vwm#ui#init(
            \ "Search Option:",
            \ {'type': 'edit', 'prefix': '  Content: ', 'id': 'text'},
            \ {'type': 'edit', 'prefix': '  Include: ', 'id': 'include'},
            \ {'type': 'edit', 'prefix': '  Exclude: ', 'id': 'exclude'},
            \ {'type': 'check', 'prefix': '  Options: ', 'items': [
                \ {'id': 'word', 'label': 'Word'},
                \ {'id': 'regex', 'label': 'Regex'},
                \ {'id': 'case', 'label': 'CaseSensitive'},
            \ ]},
        \ )

        setl signcolumn=no
        syntax match Comment /\%1l.*/
    endif

    call vwm#ui#render(g:rg_opt)
    call vwm#ui#set_focus('text')
    clearjumps
    startinsert

    setl signcolumn=yes
    setl nocursorline winhl=SignColumn:NormalFloat
endf

fun! vwm#rg#build()
    close

    let text = g:rg_opt['text']
    if empty(text) | return | endif

    call vwm#rg#open(text, g:rg_opt)
endf

fun! vwm#rg#cancel()
    sil! call jobstop(s:job_id)
    if s:job_started
        call timer_start(100, {t->vwm#rg#on_exit(s:job_id, 'break', 'on_exit')})
    endif
endf
