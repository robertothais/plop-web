class Plop.Uploader extends EventEmitter

  @className: 'Uploader'

  constructor: (@app) ->
    @ready = 
      all: false
      preparing: false
      transloadit: false
      modal: false  

    @navElem = $('.nav li.new-upload')

    @app.router.on 'uploads:show', =>        
      if @app.session.authenticated and !@ready.preparing        
        this.showModal()
      else unless @app.session.authenticated
        @app.router.emit 'registration:show', 'Tienes que entrar para poder subir una imágen', =>
          @app.router.emit 'uploads:show'    

  prepare: ->
    @ready.preparing = true

    modalPromise = $.get '/templates/upload', (data) =>
      this.prepareModal data
      @ready.modal = true

    transloaditPromise = $.getScript 'http://assets.transloadit.com/js/jquery.transloadit2.js', =>
      @ready.transloadit = true
      
    $.when(modalPromise, transloaditPromise).done =>          
      @ready.all = true      
      @ready.preparing = false  

  prepareModal: (data) ->
    @modal = $(data).modal
      show: false

    @modal.on 'show', =>
      @usernameField = @modal.find('.control-group.username')
      if this.hasUsername()
        @usernameField.hide()
      else
        @usernameField.show()

    @modal.on 'hidden', => 
      this.resetModal()
      @navElem.removeClass 'active'

    @modal.modal('show')
    
    @submitButton = @modal.find('button[type=submit]')
    @cancelButton = @modal.find('.cancel.btn')

    @cancelButton.click =>  
      if @uploading        
        @form.data('transloadit.uploader').cancel() 
        false     

    @form = @modal.find('form')
    @progress = @modal.find('.progress')

    @form.on 'submit', (e) =>
      return false if @uploading
      return false unless this.validate()
      if this.hasUsername()
        this.upload()
      else
        username = @form.find('[name=username]').val()
        @app.session.saveUsername username, (success, response) =>
          if success
            this.upload()
          else
            if response is 'duplicate'    
              this.showError('username', 'Escoge otro CTM')
      false

  validate: ->    
    errors = {}
    validateInput = (input) =>
      switch input.name
        when 'file' 
          unless input.value
            errors.file = 'Archivo requerido'
        when 'title'         
          unless input.value
            errors.title = 'Titulo requerido'
            break
          if input.value.length < 3
            errors.title = 'Titulo muy corto'
            break
          if input.value.length > 100
            errors.title = 'Titulo muy largo'
        when 'username'
          unless this.hasUsername()
            unless input.value
              errors.username = 'Nick requerido'
              break
            if input.value.length < 3
              errors.username = 'Nick muy corto'
              break
            if input.value.length > 30
              errors.username = 'Titulo muy largo'          
              break  
            unless input.value.match /^[A-Za-z0-9\-\_]+$/
              errors.username = 'Solo letras, numeros y guiones'
        when 'accept'
          unless input.checked
            errors.accept = 'Aceptar requerido'          
    validateInput input for input in this.form[0]
    $.each errors, this.showError     
    $.isEmptyObject errors    

  showError: (name, message) => 
    input = @form.find("input[name=#{name}]")
    group = input.parents('.control-group')
    field = group.find('span.error-message')
    field.text message 
    group.addClass 'error'
    input.change 'blur', -> group.removeClass 'error'
    
  bindTransloadit: ->
    @form.transloadit
      wait: true
      modal: false
      autoSubmit: false
      processZeroFiles: false
      interval: 1000
      onProgress: this.onUploadProgress
      onError: this.onUploadError
      onSuccess: this.onUploadSuccess
      onCancel: this.onCancel
    # Prevent transloadit from changing the document title
    @form.data('transloadit.uploader').documentTitle = document.title

  onUploadError: (assembly) =>
    this.doneUploading()
    if this.hasUsername() and @usernameField.is(':visible')
      @usernameField.hide()
    if assembly.error is 'MAX_SIZE_EXCEEDED'
      this.showError('file', 'El archivo que escogiste es muy grande. El límite es 4 MB.')
    else if assembly.error is 'FILE_FILTER_DECLINED_FILE'
      this.showError('file', 'El archivo que escogiste no es válido. Por favor escoge otro.')
    else
      this.showError('file', 'Hubo un error al subir el archivo. Por favor intenta de nuevo.')
      Hoptoad.notify
        message: "Upload error: #{assembly.error}"
        action: 'upload'
        params: assembly

  onUploadSuccess: (assembly) =>
    fields = {}
    fields[input.name] = input.value for input in this.form[0]
    fields.assemblyUrl = assembly.assembly_url
    delete fields.file
    delete fields.username
    this.emit 'post:create', fields
    this.doneUploading()
    this.hideModal()

  onUploadProgress: (received, expected, assembly) =>
    percent = (received / expected) * 100
    @progress.find('.bar').width("#{percent}%")
    if percent >= 100 and !@processing
      @processing = true
      if $.support.transition
        @progress.find('.bar').one $.support.transition.end, =>
          @progress.find('span').show()
      else
        @progress.find('span').show()

  onCancel: => 
    this.doneUploading()
    if this.hasUsername() and @usernameField.is(':visible')
      @usernameField.hide()        

  unbindTransloadit: ->
    iframe = @form.data('transloadit.uploader').$iframe
    uploadForm = @form.data('transloadit.uploader').$uploadForm
    iframe.remove() if iframe
    uploadForm.remove() if uploadForm
    @form.unbind 'submit.transloadit'
    @form.removeData 'transloadit.uploader'

  upload: ->
    @uploading = true
    @progress.show()
    this.bindTransloadit()
    @form.trigger 'submit.transloadit'
    # This also disables the button, which in turn
    # disables form submission
    @submitButton.button('loading')
    @modal.data('modal').isShown = false    

  doneUploading: -> 
    @modal.data('modal').isShown = true
    @submitButton.button('reset')
    this.unbindTransloadit()    
    @progress.hide()
    @progress.find('.bar').width 0
    @progress.find('span').hide()    
    @uploading = false
    @processing = false
  
  showModal: ->
    @navElem.addClass 'active'    
    if @ready.all then @modal.modal('show') else this.prepare()

  hideModal: ->
    @modal.modal 'hide'

  hasUsername: ->
    @app.session.remoteUser.username?         

  resetModal: ->
    @form[0].reset()
    @form.find('.control-group').removeClass 'error success'