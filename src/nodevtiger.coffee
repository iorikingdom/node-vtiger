###
                    Node Vtiger WebService
                
Description:        Node vtiger webservice client library
Version:            0.2.2012-06-28
Contributor:        marco.parronchi@tiwee.net
License:            public domain: http://www.nolicense.org/

Acknowledgement:    http://forge.vtiger.com/projects/vtwsclib/
                    http://vtiger.com
                    http://nodejs.org
                    http://coffeescript.org
                    https://github.com/mikeal/request/
                    http://expressjs.com
                    https://github.com/drd0rk/logger
                    
Usage:              https://wiki.vtiger.com/index.php/Webservices_tutorials

                    vtws = require('node-vtiger')
                    VT_URL = 'http://example.com/vtigercrm'
                    VT_USER = 'admin'
                    VT_ACCESSKEY = 'rFtfsdRfTgUggY' # accesskey is in your vtiger user preferences
                    client = new vtws(VT_URL, VT_USER, VT_ACCESSKEY, 'debug')
                    client.doLogin(callback)
                    client.doQuery(query, callback)
                    client.doDescribe(module, callnack)
                    client.doRetrieve(id, callback)
                    client.doUpdate(valuemap, callback)
                    client.doCreate(valuemap, callback)
                    client.doInvoke(callback, method, params) # not tested
###

crypto  = require 'crypto'
sys     = require 'util'
request = require 'request'

class NodeVtigerWS

    constructor: (url, username, accesskey, level='debug' ) ->
        @_wsUrl             = url + '/webservice.php'
        @_wsUsername        = username
        @_wsAccesskey       = accesskey
        @_wsToken           = false
        @_wsSessionName     = false
        @_wsUserId          = false
        @_isLogged          = false
        @_lastError         = false
        @_default_headers   =
            "Accept":           "application/json"
            "Content-Type":     "application/json"
            "Accept-Charset":   "utf-8"
                
        @__callback     = false
        logger  = require 'basic-logger'
        logger.setLevel level
        
        @log            = new logger( prefix: "node-vtiger")
        
        @log.debug "Vtiger_WSClient constructor"
        
    # check if the response from vtigerws has an error "success":false
    # store the error in _lastError
    __hasError: (resultdata) ->
        @log.debug "hasError"
        if resultdata?
            if resultdata.success is false
                @log.error "erreur result= #{ JSON.stringify(resultdata.error) }"
                @_lastError = resultdata.error
                return true
        else
            @log.error "result data is null"
            @_lastError = 
                "error":
                    "code":     "NULL_RESULT"
                    "message":  "Resultdata is null"
            return true
        @_lastError = false
        return false
    
    # execute callback directly or
    # with arguments if the callback is in the form
    # {function:callback, arguments:{'arg1' : 'value1'...}
    __performCallback: (callback, result) ->
        @log.debug "performCallback"
        if callback?
            callbackFunction = callback
            callbackArguments = false
            if typeof (callback) is "object"
                callbackFunction = callback.function
                callbackArguments = callback.arguments
            callbackFunction result, callbackArguments  if typeof (callbackFunction) is "function"
    
    # check if we are logged
    __checkLogin: ->
        @log.debug "checkLogin"
        if @_isLogged is false
            @log.error "isLogged = false, I quit"
            @_lastError = 
                "error":
                    "code":     "NOT_LOGGED"
                    "message":  "Try to send a request without being logged"
            return false
        else
            return true
    
    # process the respone after a request get or post
    __processResponse: (error, response, body)->
        @log.debug "processResponse "
        result = false
        if error
            @log.error "request -> error"
            @_lastError = 
                "error":
                    "code":     "REQUEST_ERROR"
                    "message":  "Error on request"
            @_lastError = error
        else if response.statusCode is not 200
            @log.error "response.statusCode is not 200"
            @_lastError = 
                "error":
                    "code":     "ERROR_REQUEST_STATUS_CODE"
                    "message":  "Error on request, statusCode = #{ response.statusCode }"
        else
            resobj = JSON.parse(body)
            if @__hasError(resobj) is false
                result = resobj.result
        #@log.debug "et je renvois" + JSON.stringify(result)
        @__performCallback(@__callback, result)
    
    lastError: ->
        return @_lastError
        
    doLogin: (callback=false) ->
        @log.debug "doLogin: #{ @_wsUsername }, #{ @_wsAccesskey }"
        @__callback = callback
        
        params = "?operation=getchallenge&username=#{@_wsUsername}"
        @log.debug @_wsUrl + params
        request @_wsUrl + params , (e, r, body) =>
            if e
                @log.error "request -> error: #{ JSON.stringify(error) }"
                @_lastError = 
                    "error":
                        "code":     "ERROR_ON_REQUEST"
                        "message":  "Error on request (get challenge)"
                @__performCallback(@__callback, false)
                return false
                
            else if r.statusCode isnt 200
                @log.error "response.statusCode is #{ r.statusCode }"
                @_lastError = 
                    "error":
                        "code":     "ERROR_REQUEST_STATUS_CODE"
                        "message":  "Error on request, statusCode = #{ r.statusCode }"
                @__performCallback(@__callback, false)
                return false
            
            # paranoid check
            try
                response = JSON.parse body
            catch ex
                @log.error body
                @log.error ex
                @__performCallback(@__callback, false)
                return false
                
            if @__hasError(response)
                @__performCallback(@__callback, false)
                return false
                
            if response.result.token is false
                @_lastError = 
                    "error":
                        "code":     "NO_TOKEN_AFTER_CHALLENGE"
                        "message":  "No token after challenge"
                @__performCallback(@__callback, false)
                return false
                
            @_wsToken = response.result.token
            
            @log.debug "POST @_wsUrl login #{@_wsUsername}"
            request.post
                url: @_wsUrl
                headers: @_default_headers
                form:
                    operation: "login"
                    username: @_wsUsername
                    accessKey: crypto.createHash("md5").update(@_wsToken + @_wsAccesskey).digest("hex")
            , (e, r, body) =>
                result = false
                if e
                    @log.error "request -> error: #{ JSON.stringify(error) }"
                    @_lastError = 
                        "error":
                            "code":     "ERROR_ON_REQUEST"
                            "message":  "Error on request (post)"

                else if r.statusCode isnt 200
                    @log.error "response.statusCode is #{ r.statusCode }"
                    @_lastError = 
                        "error":
                            "code":     "ERROR_REQUEST_STATUS_CODE"
                            "message":  "Error on request, statusCode = #{ r.statusCode }"
                else
                    resobj = JSON.parse(body)  
                    if @__hasError(resobj) is false
                        result = true
                        @_isLogged  = true
                        @_wsSessionName = resobj.result.sessionName
                        @log.debug "sessionid=" + @_wsSessionName
                        @_wsUserId    = resobj.result.userId
                @__performCallback(@__callback, result)

        return @_isLogged
    
    # query = " SELECT * FROM Leads WHERE lead_no = 'CIB883' "
    doQuery: (query, callback) ->
        @log.debug 'doQuery: ' + query
        @__callback = callback
        if not @__checkLogin()
            @__performCallback(@__callback, false)
        else
            query += ";" if query.indexOf(";") is -1
            params = '?operation=query&sessionName=' + @_wsSessionName + '&query=' + escape(query)
            @log.debug @_wsUrl + params
            request @_wsUrl + params , (e, r, body) =>
                @__processResponse(e, r, body)
    
    # return details of a module as map
    doDescribe: (module, callback) ->
        @log.debug 'doDescribe ' + module
        
        return if not @__checkLogin()
        @__callback = callback
        
        params = '?operation=describe&sessionName=' + @_wsSessionName + '&elementType=' + module
        request @_wsUrl + params , (e, r, body) =>
            @__processResponse(e, r, body)
    
    # retreive a record by his id ( in the form <moduleid>'x'<recordid> )
    doRetrieve: (id, callback) ->
        @log.debug 'doRetrieve: ' + id
        
        return if not @__checkLogin()
        @__callback = callback
        
        params = '?operation=retrieve&sessionName=' + @_wsSessionName + '&id=' + id
        request @_wsUrl + params , (e, r, body) =>
            @__processResponse(e, r, body)

    # delete a record by his id ( in the form <moduleid>'x'<recordid> )
    doDelete: (id, callback) ->
        @log.debug 'doDelete: ' + id
        
        return if not @__checkLogin()
        @__callback = callback

        request.post
            url: @_wsUrl
            headers: @_default_headers
            form:
                operation: "delete"
                id: id
                sessionName: @_wsSessionName
        , (e, r, body) =>
            result = false
            if e
                @log.error "request -> error: #{ JSON.stringify(error) }"
                @_lastError = 
                    "error":
                        "code":     "ERROR_ON_REQUEST"
                        "message":  "Error on request (post)"

            else if r.statusCode isnt 200
                @log.error "response.statusCode is #{ r.statusCode }"
                @_lastError = 
                    "error":
                        "code":     "ERROR_REQUEST_STATUS_CODE"
                        "message":  "Error on request, statusCode = #{ r.statusCode }"
            else
                resobj = JSON.parse(body)  
                result = resobj.result if @__hasError(resobj) is false

            @__performCallback(@__callback, result)


    # update a record
    doUpdate: (valuemap, callback) ->
        @log.debug "doUpdate"
        return if not valuemap?
        @__callback = callback
        if not @__checkLogin()
            @__performCallback(@__callback, false)
        else
            request.post
                url: @_wsUrl
                headers: @_default_headers
                form:
                    "operation":        "update"
                    "sessionName":     @_wsSessionName
                    "element":          JSON.stringify(valuemap)

            , (e, r, body) =>
                @__processResponse(e, r, body)
    
    # create a record
    doCreate: (module, valuemap, callback) ->
        @log.debug "doCreate: module=" + module 
        @__callback = callback
        
        if not @__checkLogin()
            @__performCallback(@__callback, false)
        else
            valuemap.assigned_user_id = @_wsUserId  unless valuemap.assigned_user_id?
            request.post
                url: @_wsUrl
                headers: @_default_headers
                form:
                    operation: "create"
                    sessionName: @_wsSessionName
                    elementType: module
                    element: JSON.stringify(valuemap)

            , (e, r, body) =>
                @__processResponse(e, r, body)
                
    # difference with vtwscli: POST only
    # not tested
    doInvoke: (callback, method, params) ->
        @log "doInvoke"
        params = {} if not params?
        postdata =
            operation: method
            sessionName: @_wsSessionName

        postdata[key] = params[key] for key of params when not (sendata[key]?)

        @__callback = callback
        if not @__checkLogin()
            @__performCallback(@__callback, false)
        else
            request.post
                url: @_wsUrl
                headers: @_default_headers
                form: postdata

            , (e, r, body) =>
                @__processResponse(e, r, body)

module.exports = NodeVtigerWS