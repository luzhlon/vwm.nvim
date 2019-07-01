
let g:vwm_bookmarks = {}

" 一个buffer中的bookmark什么时候需要更新？
"   1. bookmark有变动时，也就是toggle时。但是如果buffer如果modified了，则不算数
"   2. buffer保存时，如果内容发生了变化，bookmark的位置也需要更新

fun! vwm#bm#init()
    hi default VwmBookmarkSign guifg=#0a9dff
    hi default VwmBookmarkLabelSign guifg=#0a9dff

    call sign_define('VwmBookmark', {'text': get(g:, 'vwm#bm#bm_sign', '⚑'), 'texthl': 'VwmBookmarkSign'})
    call sign_define('VwmBookmarkLabel', {'text': get(g:, 'vwm#bm#bm_sign', '☰'), 'texthl': 'VwmBookmarkLabelSign'})

    au User VwmSessionLoad call vwm#bm#load()
    au User VwmSessionSave call vwm#bm#save()
endf

fun! vwm#bm#toggle(...)
    let lnum = line('.')
    let bookmark = sign_getplaced('%', {'group': 'VwmBookmark', 'lnum': lnum})[0].signs
    let bookmark = len(bookmark) ? bookmark[0] : {}

    let label = a:0 ? a:1 == 'label' : 0
    if empty(bookmark)
        let b:bookmarks_id = get(b:, 'bookmarks_id') + 1
        call vwm#bm#place_sign(b:bookmarks_id, lnum, label ? input('Bookmark Label: ') : '')
        echo 'Add' 'Bookmark' 'Success'
    else
        call vwm#bm#unplace_sign(bookmark.id)
        echo 'Remove' 'Bookmark' 'Success'
    endif

    if &modified
    else
        call vwm#bm#cache()
    endif
endf

fun! s:jump_next(d)
    let i = 0
    let bookmarks = vwm#bm#list_signs()
    let bookmarks = a:d < 0 ? reverse(bookmarks) : bookmarks
    let lnum = line('.')
    for item in bookmarks
        if (a:d > 0 ? item.lnum > lnum : item.lnum < lnum)
            break
        endif
        let i += 1
    endfor
    let bookmark = get(bookmarks, i)
    if !empty(bookmark)
        call sign_jump(bookmark.id, 'VwmBookmark', '%')
    endif
endf

fun! vwm#bm#jump_prev()
    call s:jump_next(-1)
endf

fun! vwm#bm#jump_next()
    call s:jump_next(1)
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
    if empty(g:vwm_bookmarks)
        sil! unlet g:vwm_session.bookmarks
    else
        let g:vwm_session.bookmarks = g:vwm_bookmarks
    endif
endf

fun! vwm#bm#clear()
    if 1 == confirm('Clear All Bookmarks?', "&Yes\n&No\n&Cancel", 2)
        let g:vwm_bookmarks = {}
    endif
endf

fun! vwm#bm#copen()
    cexpr 'Vwm Bookmarks:'
    let count = 0
    for [path, bookmarks] in items(g:vwm_bookmarks)
        let items = map(copy(bookmarks), {i,v->
            \ {'filename': path, 'lnum': v.lnum, 'text': get(v, 'label', get(v, 'text'))}})
        let count += len(items)
        call setqflist(items, 'a')
    endfor

    if count | copen | endif
endf

fun! vwm#bm#curpath()
    let path = expand('%:.')
    return substitute(path, '\\', '/', 'g')
endf

" 列出buffer中的bookmarks
fun! vwm#bm#list_signs()
    return sign_getplaced('%', {'group': 'VwmBookmark'})[0].signs
endf

fun! s:sign_to_bm(sign)
    let s = a:sign
    let id = s.id
    let s.text = getline(s.lnum)
    if has_key(b:, 'bookmark_labels') && has_key(b:bookmark_labels, id)
        let s.label = b:bookmark_labels[id]
    endif
    return s
endf

" 缓存当前buffer中的书签
fun! vwm#bm#cache()
    if len(&bt) | return | endif

    let path = vwm#bm#curpath()
    let bookmarks = map(vwm#bm#list_signs(), {i,v->s:sign_to_bm(v)})
    if empty(bookmarks)
        sil! call remove(g:vwm_bookmarks, path)
    else
        let g:vwm_bookmarks[path] = bookmarks
    endif
endf

" 还原当前buffer中的书签
fun! vwm#bm#restore()
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
        call vwm#bm#place_sign(id, item.lnum, label)
    endfor
endf

fun! vwm#bm#place_sign(id, lnum, label)
    let id = a:id
    call sign_place(id, 'VwmBookmark',
        \ (empty(a:label) ? 'VwmBookmark' : 'VwmBookmarkLabel'), '%',
        \ {'lnum': a:lnum, 'priority': get(g:, 'vwm#bm#sign_priority', 100)})

    if !empty(a:label)
        if !has_key(b:, 'bookmark_labels')
            let b:bookmark_labels = {}
        endif
        let b:bookmark_labels[a:id] = a:label
    endif
endf

fun! vwm#bm#unplace_sign(id)
    let id = a:id
    call sign_unplace('VwmBookmark', {'buffer': '%', 'id': id})
endf

fun! vwm#bm#check(event)
    let bookmarks = get(g:vwm_session, 'bookmarks')
    if empty(bookmarks) | return | endif

    let path = vwm#bm#curpath()
    if a:event == 'BufWritePost'
        call vwm#bm#cache()
    elseif a:event == 'BufRead'
        call vwm#bm#restore()
    endif
endf
