{CompositeDisposable} = require 'atom'
{spawn} = require 'child_process'
Dialog = require './dialog'
shell = require 'shell'

module.exports = AtomHugo =
  subscriptions: null
  serverCmd: null

  config:
    site:
      type: 'object'
      order: 1
      properties:
        format:
          type: 'string'
          default: 'toml'
          enum: ['yaml', 'json', 'toml']
          title: 'Format'
          description: 'Config frontmatter format'
    build:
      type: 'object'
      order: 2
      properties:
        buildDrafts:
          type: 'boolean'
          default: false
          title: 'Build drafts'
          description: 'Include content marked as draft'
        buildExpired:
          type: 'boolean'
          default: false
          title: 'Build expired'
          description: 'Include expired content'
        buildFuture:
          type: 'boolean'
          default: false
          title: 'Build future'
          description: 'Include content with publishdate in the future'
        watch:
          type: 'boolean'
          default: false
          title: 'Watch'
          description: 'Watch filesystem for changes and recreate as needed'
    server:
      type: 'object'
      order: 3
      properties:
        buildDrafts:
          type: 'boolean'
          default: false
          title: 'Build drafts'
          description: 'Include content marked as draft'
        buildExpired:
          type: 'boolean'
          default: false
          title: 'Build expired'
          description: 'Include expired content'
        buildFuture:
          type: 'boolean'
          default: false
          title: 'Build future'
          description: 'Include content with publishdate in the future'
        watch:
          type: 'boolean'
          default: true
          title: 'Watch'
          description: 'Watch filesystem for changes and recreate as needed'

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace',
      'atom-hugo:new': => @new()
      'atom-hugo:new-site': => @newSite()
      'atom-hugo:build': => @build()
      'atom-hugo:server': => @server()
      'atom-hugo:kill-server': => @killServer()

  deactivate: ->
    @subscriptions.dispose()
    killServer()

  new: ->
    dialog = new Dialog {
      initialPath: 'post/'
      prompt: 'Create new content for your site'
    }
    dialog.onConfirm = (path) ->
      # Spawn "hugo new [path] [flags]"
      cmd = spawn 'hugo', ['new', path, "-s=#{atom.project.getPaths()[0]}"]

      # Show notifications for output and error messages
      cmd.stdout.on 'data', (data) -> atom.notifications.addSuccess data.toString()
      cmd.stderr.on 'data', (data) -> atom.notifications.addError data.toString()

      dialog.close()

    dialog.attach()

  newSite: ->
    dialog = new Dialog {
      initialPath: atom.config.get('core.projectHome')
      prompt: 'Create a new site (skeleton)'
    }
    dialog.onConfirm = (path) ->
      # Spawn "hugo new site [path] [flags]"
      cmd = spawn 'hugo', ['new', 'site', path, "-f=#{atom.config.get('atom-hugo.site.format')}"]

      # Show notifications for output and error messages
      cmd.stdout.on 'data', (data) -> atom.notifications.addSuccess data.toString()
      cmd.stderr.on 'data', (data) -> atom.notifications.addError data.toString()

      dialog.close()

    dialog.attach()

  build: ->
    # Spawn hugo [flags]
    cmd = spawn 'hugo', [
      "-s=#{atom.project.getPaths()[0]}",
      "-D=#{atom.config.get('atom-hugo.build.buildDrafts')}",
      "-E=#{atom.config.get('atom-hugo.build.buildExpired')}",
      "-F=#{atom.config.get('atom-hugo.build.buildFuture')}",
      "-w=#{atom.config.get('atom-hugo.build.watch')}"
    ]

    # Show notifications for output and error messages
    cmd.stdout.on 'data', (data) -> atom.notifications.addSuccess data.toString()
    cmd.stderr.on 'data', (data) -> atom.notifications.addError data.toString()

  server: ->
    # Check if server is already running and kill it
    @killServer()

    @serverCmd = spawn 'hugo', [
      'server',
      "-s=#{atom.project.getPaths()[0]}",
      "-D=#{atom.config.get('atom-hugo.server.buildDrafts')}",
      "-E=#{atom.config.get('atom-hugo.server.buildExpired')}",
      "-F=#{atom.config.get('atom-hugo.server.buildFuture')}",
      "-w=#{atom.config.get('atom-hugo.server.watch')}",
      "-p=2897"
    ]

    # Show notifications for output and error messages
    @serverCmd.stdout.on 'data', (data) ->
      resultString = data.toString()
      resultUrl = resultString.match(RegExp(/(?:(?:https?|ftp|file):\/\/|www\.|ftp\.)(?:\([-A-Z0-9+&@#\/%=~_|$?!:,.]*\)|[-A-Z0-9+&@#\/%=~_|$?!:,.])*(?:\([-A-Z0-9+&@#\/%=~_|$?!:,.]*\)|[A-Z0-9+&@#\/%=~_|$])/igm))
      if resultUrl != null and resultUrl.length > 0 then shell.openExternal(resultUrl[0]) else null
      atom.notifications.addSuccess resultString
    @serverCmd.stderr.on 'data', (data) -> atom.notifications.addError data.toString()


  killServer: ->
    if @serverCmd != null then @serverCmd.kill()
