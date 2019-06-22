
fun! vwm#ui#init(...)
    if !has_key(b:, 'ui_items')
        setl nonu nobl bt=nowrite
        setl modifiable cursorline signcolumn=no

        let b:ui_items = a:000
        let b:ui_edits = {}     " 行号：Edit
        let b:ui_ctrls = {}     " ID: Ctrl
        let b:ui_checks = {}
        let b:cursor_line = line('.')
        let b:cursor_col = col('.')

        ino <expr><del> col('.')==col('$')?'':"\<del>"
        ino       <c-k> <c-o>D

        " au! * <buffer>
        au CursorMovedI <buffer> call vwm#ui#check_cursor()
        au TextChangedI <buffer> call vwm#ui#check_change()
        au BufWipeout,WinLeave <buffer> call vwm#ui#save_vals()
    endif
    startinsert
endf

fun! vwm#ui#render(vals)
    setl undolevels=-1
    let b:ui_vals = a:vals
    let lines = []

    let i = 1
    for Item in b:ui_items
        if type(Item) == v:t_func
            let text = Item()
        elseif type(Item) == v:t_string
            let text = Item
        elseif type(Item) == v:t_dict
            let id = get(Item, 'id', '')
            let Item.line = i
            if len(id) | let b:ui_ctrls[id] = Item | endif

            let item_type = get(Item, 'type', '')
            let prefix = get(Item, 'prefix', '')
            let content = ''
            if item_type == 'edit'
                let b:ui_edits[i] = Item
                let text = vwm#ui#render_edit(Item)
            elseif item_type == 'check'
                for box in get(Item, 'items', [Item])
                    let id = get(box, 'id', '')
                    let box.type = 'check'
                    let box.line = i
                    let b:ui_vals[id] = get(b:ui_vals, id)
                    if len(id) | let b:ui_ctrls[id] = box | endif
                endfor
                let text = vwm#ui#render_checkbox(Item)
            endif
        else
            break
        endif

        call add(lines, text)
        let i += 1
    endfor

    call setline(1, lines)
    setl undolevels=1
endf

fun! vwm#ui#render_edit(item)
    let content = get(b:ui_vals, a:item['id'], '')
    return get(a:item, 'prefix', '') . content
endf

fun! vwm#ui#toggle_checkbox(id)
    let box = get(b:ui_ctrls, a:id, {})
    let b:ui_vals[a:id] = !get(b:ui_vals, a:id)
    let l = box['line']
    call setline(l, vwm#ui#render_checkbox(b:ui_items[l-1]))
    return ''
endf

fun! vwm#ui#render_checkbox(item)
    let box_text = []
    for box in get(a:item, 'items', [a:item])
        call add(box_text,
            \ printf('[%s] %s',
                    \ get(b:ui_vals, box['id']) ? '': ' ',
                    \ get(box, 'label', '')))
    endfor
    return get(a:item, 'prefix', '') . join(box_text, get(a:item, 'sep', ', '))
endf

" 刷新buffer内容
fun! vwm#ui#update(...)
    let action = a:0 ? a:1 : ''

    let i = 1
    for Item in b:ui_items
        if type(Item) == v:t_func
            let text = Item()
            call setline(i, text)
        elseif type(Item) == v:t_string
            let text = Item
        elseif type(Item) == v:t_dict
            let item_type = get(Item, 'type', '')
            if item_type == 'edit'
                let b:ui_edits[i] = Item
                let Item.line = i
                let id = get(Item, 'id', '')
                if len(id) | let b:ui_edits[id] = Item | endif

                let label = get(Item, 'label', '')
                if action == 'all'
                    let text = label . getline(i)[len(label):]
                    call setline(i, text)
                endif
            elseif item_type == 'check'
            endif
        else
            break
        endif

        let i += 1
    endfor
endf

" 检查光标位置
fun! vwm#ui#check_cursor()
    call vwm#ui#move_to_focus(line('.') - b:cursor_line >= 0 ? 1: -1)

    let edit = get(b:ui_edits, line('.'), {})
    let prefix = get(edit, 'prefix', '')
    if col('.') <= len(prefix)
        call cursor(line('.'), len(prefix) + 1)
    endif

    let b:cursor_line = line('.')
    let b:cursor_col = col('.')
endf

" 检查文本更改
fun! vwm#ui#check_change()
    let edit = get(b:ui_edits, line('.'), {})
    let prefix = get(edit, 'prefix', '')
    if col('$') <= len(prefix)
        call setline('.', prefix)
        call cursor(line('.'), col('$'))
    endif
endf

" 获取Edit输入的Text
fun! vwm#ui#get_text(id)
    let edit = get(b:ui_ctrls, a:id, {})
    if !empty(edit)
        let t = getline(edit['line'])
        return t[len(get(edit, 'prefix', '')):]
    endif
endf

fun! vwm#ui#set_focus(id)
    let edit = type(a:id) == v:t_dict ? a:id : get(b:ui_edits, a:id, {})
    if !empty(edit)
        call cursor(edit['line'], col('.'))
        call cursor(line('.'), col('$'))
    endif
endf

fun! s:is_focus_able(item)
    return type(a:item) == v:t_dict && get(a:item, 'type', '') == 'edit'
endf

fun! vwm#ui#move_to_focus(dir)
    let i = line('.') - 1
    let Item = b:ui_items[i]
    if s:is_focus_able(Item)
        return
    endif

    while 1
        if s:is_focus_able(Item)
            break
        endif
        let i += a:dir
        let i = i > 0 ? i % len(b:ui_items): i
        let Item = b:ui_items[i]
    endw
    call vwm#ui#set_focus(Item)
endf

fun! vwm#ui#save_vals()
    for Item in b:ui_items
        if type(Item) == v:t_dict
            let item_type = get(Item, 'type', '')
            let id = get(Item, 'id')
            if empty(id) | continue | endif

            if item_type == 'check'
                let b:ui_vals[id] = get(b:ui_vals, id)
            elseif item_type == 'edit'
                let b:ui_vals[id] = vwm#ui#get_text(id)
            endif
        endif
    endfor
endf
