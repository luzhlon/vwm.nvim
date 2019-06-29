
let g:vwm#bm#sign_id = 80000
let g:vwm_bookmarks = {}

" 一个buffer中的bookmark什么时候需要更新？
"   1. bookmark有变动时，也就是toggle时。但是如果buffer如果modified了，则不算数
"   2. buffer保存时，如果内容发生了变化，bookmark的位置也需要更新

fun! vwm#bm#init()
    sign define VwmBookmark text=⚑
    sign define VwmBookmarkLabel text=☰

    au User VwmSessionLoad call vwm#bm#load()
    au User VwmSessionSave call vwm#bm#save()
endf

fun! vwm#bm#toggle(...)
    let l = line('.')
    let bookmark = 0
    fun! Callback(item) closure
        if a:item.line != l
            return 1
        endif
        let bookmark = a:item
    endf
    call vwm#bm#each_sign(funcref('Callback'))

    let label = a:0 ? a:1 == 'label' : 0
    if empty(bookmark)
        let b:bookmarks_id = get(b:, 'bookmarks_id') + 1
        call vwm#bm#place_sign(b:bookmarks_id, l, label ? input('Bookmark Label: ') : '')
        echo 'Add' 'Bookmark' 'Success'
    else
        call vwm#bm#unplace(bookmark.id)
        echo 'Remove' 'Bookmark' 'Success'
    endif

    if &modified
    else
        call vwm#bm#cache()
    endif
endf

fun! vwm#bm#load()
    let bookmarks = get(g:vwm_session, 'bookmarks')
    if empty(bookmarks) | return | endif

    let g:vwm_bookmarks = bookmarks
    call timer_start(0, {t->vwm#bm#check('BufRead')})

    au BufRead * call vwm#bm#check('BufRead')
    au BufWritePost * call vwm#bm#check('BufWritePost')
endf

fun! vwm#bm#save()
    if empty(g:vwm_bookmarks) | return | endif
    let g:vwm_session.bookmarks = g:vwm_bookmarks
endf

fun! vwm#bm#copen()
    cexpr 'Vwm Bookmarks:'
    let count = 0
    for [path, bookmarks] in items(g:vwm_bookmarks)
        let items = map(copy(bookmarks), {i,v->
            \ {'filename': path, 'lnum': v.line, 'text': get(v, 'label', get(v, 'text'))}})
        let count += len(items)
        call setqflist(items, 'a')
    endfor

    if count | copen | endif
endf

fun! vwm#bm#curpath()
    let path = expand('%:.')
    return substitute(path, '\\', '/', 'g')
endf

fun! vwm#bm#each_sign(callback)
    let labels = get(b:, 'bookmark_labels', {})
    for item in sign_getplaced('%', {'group': 'VwmBookmark'})[0].signs
        let lnum = item.lnum
        let id = item.id
        let name = item.name

        let id = id - g:vwm#bm#sign_id
        let item = {'line': lnum, 'id': id, 'text': getline(lnum)}
        if has_key(labels, id)
            let item.label = labels[id]
        endif

        if empty(a:callback(item))
            break
        endif
    endfor
endf

" 列出buffer中的bookmarks
fun! vwm#bm#list_signs()
    let result = []
    call vwm#bm#each_sign({item->add(result, item)})
    return result
endf

fun! vwm#bm#cache()
    let path = vwm#bm#curpath()
    let bookmarks = vwm#bm#list_signs()
    if empty(bookmarks)
        sil! call remove(g:vwm_bookmarks, path)
    else
        let g:vwm_bookmarks[path] = bookmarks
    endif
endf

fun! vwm#bm#place_sign(id, line, label)
    let id = a:id + g:vwm#bm#sign_id
    call sign_place(id, 'VwmBookmark',
        \ (empty(a:label) ? 'VwmBookmark' : 'VwmBookmarkLabel'), '%',
        \ {'lnum': a:line, 'priority': get(g:, 'vwm#bm#sign_priority', 100)})

    if !empty(a:label)
        if !has_key(b:, 'bookmark_labels')
            let b:bookmark_labels = {}
        endif
        let b:bookmark_labels[a:id] = a:label
    endif
endf

fun! vwm#bm#unplace(id)
    let id = a:id + g:vwm#bm#sign_id
    call sign_unplace('VwmBookmark', {'buffer': '%', 'id': id})
endf

fun! vwm#bm#check(event)
    let bookmarks = get(g:vwm_session, 'bookmarks')
    if empty(bookmarks) | return | endif

    let path = vwm#bm#curpath()
    if a:event == 'BufWritePost'
        " 文件Buffer && 文件已保存
        if empty(&bt)
            call vwm#bm#cache()
        endif
    elseif a:event == 'BufRead'
        if has_key(bookmarks, path)
            let bookmarks = get(g:vwm_bookmarks, vwm#bm#curpath())
            if empty(bookmarks) | return | endif

            let b:bookmarks_id = 0
            let b:bookmark_labels = {}
            " place signs
            for item in bookmarks
                let id = item.id
                let b:bookmarks_id = max([id, b:bookmarks_id])

                let label = get(item, 'label')
                if !empty(label)
                    let b:bookmark_labels[id] = label
                endif
                call vwm#bm#place_sign(id, item.line, label)
            endfor
        endif
    endif
endf
