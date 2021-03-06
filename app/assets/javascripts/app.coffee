#= require jquery
#= require jquery_ujs
#= require jquery.turbolinks.min
#= require bootstrap.min
#= require underscore
#= require backbone
#= require will_paginate
#= require jquery.timeago
#= require jquery.timeago.settings
#= require jquery.hotkeys
#= require jquery.chosen
#= require jquery.autogrow-textarea
#= require jquery.html5-fileupload
#= require jquery.fluidbox.min
#= require social-share-button
#= require jquery.atwho
#= require emoji_list
#= require faye
#= require notifier
#= require form_storage
#= require turbolinks
#= require topics
#= require pages
#= require notes
#= require_self

AppView = Backbone.View.extend
  el: "body"
  repliesPerPage: 50

  events:
    "click a.likeable": "likeable"
    "click .header .form-search .btn-search": "openHeaderSearchBox"
    "click .header .form-search .btn-close": "closeHeaderSearchBox"

  initialize: ->
    FormStorage.restore()
    @initForDesktopView()
    @initComponents()
    @initNotificationSubscribe()

    if $('body').data('controller-name') in ['topics', 'replies']
      window._topicView = new TopicView({parentView: @})

    if $('body').data('controller-name') in ['pages']
      window._pageView = new PageView({parentView: @})

    if $('body').data('controller-name') in ['notes']
      window._noteView = new NoteView({parentView: @})

  initComponents: () ->
    $("abbr.timeago").timeago()
    $(".alert").alert()
    $('.dropdown-toggle').dropdown()
    $("select").chosen()

    # 绑定评论框 Ctrl+Enter 提交事件
    $(".cell_comments_new textarea").unbind "keydown"
    $(".cell_comments_new textarea").bind "keydown","ctrl+return",(el) ->
      if $(el.target).val().trim().length > 0
        $(el.target).parent().parent().submit()
      return false

  initForDesktopView : () ->
    return if typeof(app_mobile) != "undefined"
    $("a[rel=twipsy]").tooltip()

    # CommentAble @ 回复功能
    commenters = App.scanLogins($(".cell_comments .comment .info .name a"))
    commenters = ({login: k, name: v, search: "#{k} #{v}"} for k, v of commenters)
    App.atReplyable(".cell_comments_new textarea", commenters)

  likeable : (e) ->
    if !App.isLogined()
      location.href = "/account/sign_in"
      return false

    $el = $(e.currentTarget)
    likeable_type = $el.data("type")
    likeable_id = $el.data("id")
    likes_count = parseInt($el.data("count"))
    if $el.data("state") != "followed"
      $.ajax
        url : "/likes"
        type : "POST"
        data :
          type : likeable_type
          id : likeable_id

      likes_count += 1
      $el.data('count', likes_count)
      @likeableAsLiked($el)
    else
      $.ajax
        url : "/likes/#{likeable_id}"
        type : "DELETE"
        data :
          type : likeable_type
      if likes_count > 0
        likes_count -= 1
      $el.data("state","").data('count', likes_count).attr("title", "喜欢").removeClass("followed")
      if likes_count == 0
        $('span',$el).text("喜欢")
      else
        $('span',$el).text("#{likes_count} 人喜欢")
      $("i.fa",$el).attr("class","fa fa-heart-o")
    false

  likeableAsLiked : (el) ->
    likes_count = el.data("count")
    el.data("state","followed").attr("title", "取消喜欢").addClass("followed")
    $('span',el).text("#{likes_count} 人喜欢")
    $("i.fa",el).attr("class","fa fa-heart")


  initNotificationSubscribe : () ->
    return if not App.faye_client_url
    return if not App.access_token?
    faye = new Faye.Client(App.faye_client_url)
    faye.subscribe "/notifications_count/#{App.access_token}", (json) ->
      span = $("#user_notifications_count span")
      new_title = document.title.replace(/^\(\d+\) /,'')
      if json.count > 0
        span.addClass("badge-error")
        new_title = "(#{json.count}) #{new_title}"
        url = App.fixUrlDash("#{App.root_url}#{json.content_path}")
        console.log url
        $.notifier.notify("",json.title,json.content,url)
      else
        span.removeClass("badge-error")
      span.text(json.count)
      document.title = new_title
    true

  openHeaderSearchBox: (e) ->
    $(".header .form-search").addClass("active")
    $(".header .form-search input").focus()
    return false

  closeHeaderSearchBox: (e) ->
    $(".header .form-search input").val("")
    $(".header .form-search").removeClass("active")
    return false


window.App =
  notifier : null
  current_user_id: null
  access_token : ''
  faye_client_url : ''
  asset_url : ''
  root_url : ''

  isLogined : ->
    App.current_user_id != null

  loading : () ->
    console.log "loading..."

  fixUrlDash : (url) ->
    url.replace(/\/\//g,"/").replace(/:\//,"://")

  # 警告信息显示, to 显示在那个dom前(可以用 css selector)
  alert : (msg,to) ->
    $(".alert").remove()
    $(to).before("<div class='alert alert-warning'><a class='close' href='#' data-dismiss='alert'>X</a>#{msg}</div>")

  # 成功信息显示, to 显示在那个dom前(可以用 css selector)
  notice : (msg,to) ->
    $(".alert").remove()
    $(to).before("<div class='alert alert-success'><a class='close' data-dismiss='alert' href='#'>X</a>#{msg}</div>")

  openUrl : (url) ->
    window.open(url)

  # Use this method to redirect so that it can be stubbed in test
  gotoUrl: (url) ->
    Turbolinks.visit(url)

  # scan logins in jQuery collection and returns as a object,
  # which key is login, and value is the name.
  scanLogins: (query) ->
    result = {}
    for e in query
      $e = $(e)
      result[$e.text()] = $e.attr('data-name')
    result

  atReplyable : (el, logins) ->
    return if logins.length == 0
    $(el).atwho
      at : "@"
      data : logins
      search_key : "search"
      tpl : "<li data-value='${login}'>${login} <small>${name}</small></li>"
    .atwho
      at : ":"
      data : window.EMOJI_LIST
      tpl : "<li data-value='${name}:'><img src='#{App.asset_url}/assets/emojis/${name}.png' height='20' width='20'/> ${name} </li>"
    true

$(document).on 'page:change',  ->
  window._appView = new AppView()

FormStorage.init()
