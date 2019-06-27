
let g:vwm#ss#directory = expand(get(g:, 'vwm#ss#directory', '~/.cache/vwm-session'))

fun! vwm#ss#init()
    au VimLeavePre * call vwm#ss#save()
endf

fun! vwm#ss#add_history(dir)
    let dir = a:dir
    let history_dir = proj#get_history()
    if has('win32')
        let dir = substitute(dir, '\/', '\', 'g')
        call map(history_dir, {i,v->substitute(v, '\/', '\', 'g')})
    endif

    " 将最近添加的移到列表头部
    for i in range(0, len(history_dir) - 1)
        let item = get(history_dir, i, '')
        if has('win32') ? item ==? dir : item ==# dir
            call remove(history_dir, i)
        endif
        " 移除不存在的目录
        if len(item) && !isdirectory(item)
            call remove(history_dir, i)
        endif
    endfor
    call insert(history_dir, dir, 0)
    call writefile(history_dir, s:history_path)
endf

fun! vwm#ss#load()
endf

fun! vwm#ss#save()
    if !isdirectory(g:vwm#ss#directory)
        call mkdir(g:vwm#ss#directory, 'p')
    endif
endf

fun! vwm#ss#config(file, ...)
    let file = g:Proj.confdir . (has('win32') ? '\': '/') . a:file
    if a:0
        return s:writejson(file, a:1)
    else
        return s:readjson(file)
    endif
endf

fun! s:save_info()
    let max = has('nvim') ? get(g:, 'GuiWindowMaximized') : (has('gui_running') && getwinposx()<0 && getwinposy()<0)
    let data = {'max': max}
    if &title && len(&titlestring)
        let data.title = &titlestring
    endif

    " All Buffers
    let data.buffers = map(filter(getbufinfo({'buflisted': 1}),
                                \ {i,v->empty(getbufvar(v['bufnr'], '&bt')) && len(v['name'])}),
                         \ {i,v->s:buf_line_name(v)})

    " Current Buffer
    for i in range(1, winnr('$'))
        let bnr = winbufnr(i)
        if empty(&bt)
            let data.current = s:buf_line_name(getbufinfo(bufnr('%'))[0])
            break
        elseif empty(getbufvar(bnr, '&bt'))
            let data.current = s:buf_line_name(getbufinfo(bnr)[0])
            break
        endif
    endfor

    call proj#config('gui.json', data)
endf
