
let g:vwm#ss#directory = expand(get(g:, 'vwm#ss#directory', '~/.cache/vwm-session'))
let g:vwm_ss_histpath = g:vwm#ss#directory . '/history.txt'

fun! vwm#ss#init()
    com! VwmSessionToggle call vwm#ss#toggle()
    com! -bang -nargs=+ -complete=dir VwmSession call vwm#ss#load(<q-args>, '<bang>' == '!')
    com! -bang VwmSessionSave call vwm#ss#save('<bang>' == '!')
    au VimLeavePre * call vwm#ss#save(0)

    if argc()
        let g:vwm_ss_disabled = 1 | return
    endif

    let remove_path = s:get_remove_path()
    if filereadable(remove_path) | return | endif

    if v:vim_did_enter
        call vwm#ss#load('.', 0)
    else
        au VimEnter * ++nested call vwm#ss#load('.', 0)
    endif
endf

fun! vwm#ss#load(dir, force)
    if !a:force
        if vwm#ss#ignored(a:dir) | return | endif
    endif

    call s:clear_session()

    if isdirectory(a:dir)
        exec 'cd' a:dir
    else
        echoerr a:dir 'is not exists'
        return
    endif

    if !empty(vwm#ss#read())
        call s:load_info()
        call s:local_config()
        call vwm#ss#histadd(getcwd())
        doautocmd User VwmSessionLoad
        let g:vwm_ss_loaded = 1
    endif
endf

fun! vwm#ss#ignored(dir)
    let path = substitute(a:dir, '\\', '/', 'g')
    for ignore in get(g:, 'vwm#ss#ignore', ['~'])
        for p in glob(ignore, 0, 1)
            let p = substitute(p, '\\', '/', 'g')
            if has('win32') ? p ==? path : p ==# path
                return 1
            endif
        endfor
    endfor
endf

fun! vwm#ss#save(force)
    if !a:force
        if vwm#ss#ignored(getcwd()) | return | endif

        let remove_path = s:get_remove_path()
        if get(g:, 'vwm_ss_disabled') || filereadable(remove_path)
            return
        endif
    endif

    let g:vwm_session = get(g:, 'vwm_session', {})
    try
        doautocmd User VwmSessionSave
        call s:save_info()
        call vwm#ss#write()
        call vwm#ss#histadd(getcwd())
    catch
        echo v:exception | call getchar()
    endt
endf

fun! vwm#ss#toggle()
    let path = vwm#ss#path()
    let remove_path = s:get_remove_path()
    if filereadable(remove_path)
        if rename(remove_path, path)
            echoerr remove_path '->' path 'FAILURE'
            return
        endif
        echo 'Enable' 'Success'
    elseif filereadable(path)
        if rename(path, remove_path)
            echoerr path '->' remove_path 'FAILURE'
            return
        endif
        echo 'Disable' 'Success'
    else
        call writefile([], remove_path)
    endif
endf

fun! vwm#ss#histadd(dir)
    let dir = a:dir
    let history_dir = vwm#ss#history()
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
            call delete(vwm#ss#path(item))
        endif
    endfor
    call insert(history_dir, dir, 0)
    call writefile(history_dir, g:vwm_ss_histpath)
endf

fun! vwm#ss#history()
    let cache_file = g:vwm_ss_histpath
    return filereadable(cache_file) ? readfile(cache_file) : []
endf

fun! vwm#ss#startify()
    return map(vwm#ss#history()[0:10], {i,v->{'cmd': 'VwmSession', 'path': v, 'line': v}})
endf

fun! vwm#ss#path(...)
    let cwd = a:0 ? a:1 : getcwd()
    let filename = substitute(cwd, '[\\\/:]', '=', 'g')
    return g:vwm#ss#directory . '/' . filename
endf

fun! s:get_remove_path()
    let path = vwm#ss#path()
    return fnamemodify(path, ':h') . '_' . fnamemodify(path, ':t')
endf

fun! vwm#ss#read()
    let path = vwm#ss#path()
    let g:vwm_session = filereadable(path) ?
        \ json_decode(join(readfile(path), "\n")) : {}
    return g:vwm_session
endf

fun! vwm#ss#write()
    if !isdirectory(g:vwm#ss#directory)
        call mkdir(g:vwm#ss#directory, 'p')
    endif

    return writefile([json_encode(g:vwm_session)], vwm#ss#path())
endf

fun! s:buf_line_name(info)
    let v = a:info
    return '+' . v['lnum'] . ' ' . fnamemodify(v['name'], ':.')
endf

" TODO: save window's layout via winlayout()
" TODO: &columns &lines
fun! s:save_info()
    let wid = win_getid()
    let data = {'left_panel': 0, 'bottom_panel': 0}

    if win_gotoid(g:vwm_bottom_panel)
        let data.bottom_panel = 1 | close
    endif
    if win_gotoid(g:vwm_left_panel)
        let data.left_panel = 1 | close
    endif

    let data.max = has('nvim') ? get(g:, 'GuiWindowMaximized') :
           \ (has('gui_running') && getwinposx() < 0 && getwinposy() < 0)

    " All Buffers
    let data.buffers = map(filter(getbufinfo({'buflisted': 1}),
            \ {i,v->empty(getbufvar(v['bufnr'], '&bt')) && len(v['name'])}),
     \ {i,v->s:buf_line_name(v)})

    " Current Buffer
    call vwm#goto_normal_window()
    if empty(&bt) && len(bufname('%'))
        let data.current = s:buf_line_name(getbufinfo(bufnr('%'))[0])
    endif

    let g:vwm_session.core_info = data
endf

fun! s:clear_session()
    if get(g:, 'vwm_ss_loaded')
        call vwm#ss#save(0)
    endif
    if win_gotoid(g:vwm_left_panel)
        bwipe
    endif
    sil! windo bwipe
    bufdo confirm bwipe
endf

fun! s:load_info()
    let data = get(g:vwm_session, 'core_info')
    if empty(data) | return | endif

    let max = get(data, 'max')
    if max && exists('*GuiWindowMaximized')
        call GuiWindowMaximized(1)
    endif

    for path in get(data, 'buffers', [])
        exec 'badd' path
    endfor

    " Empty buffer [No Name]
    if empty(expand('%')) && !&modified && line('$') <= 1 && empty(getline(1))
        set bh=wipe
    endif

    if has_key(data, 'current')
        exec 'b' data['current']
    endif

    " if get(data, 'bottom_panel')
    "     call timer_start(100, {t->vwm#open_bottom_panel()})
    " endif
    if get(data, 'left_panel')
        Defx -split=vertical -direction=topleft -search=`expand('%:p')`
    endif

    call timer_start(0, {t->vwm#goto_normal_window()})
endf

fun! s:local_config()
    let f = get(g:, 'vwm#ss#confdir', '.vim') . '/' . get(g:, 'vwm#ss#confile', 'settings.vim')
    if filereadable(f)
        exec 'so' f
    endif
endf
