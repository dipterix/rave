#' Module runtime environment (session based)
#' @export
ExecEnvir <- R6::R6Class(
  classname = 'ExecEnvir',
  portable = FALSE,
  cloneable = TRUE,
  private = list(
    module_env = NULL,
    data_env = NULL,
    session = NULL,
    cache_env = NULL,
    inputs = NULL,
    outputs = NULL,
    update = NULL,
    tabsets = NULL,
    executes = NULL
  ),
  public = list(
    parent_env = NULL,
    wrapper_env = NULL,
    static_env = NULL,
    runtime_env = NULL,
    parse_env = NULL,
    param_env = NULL,
    ns = NULL,
    auto_execute = TRUE,
    input_update = NULL,
    register_output_events = NULL,
    register_input_events = NULL,
    execute = NULL,
    async_module = FALSE,
    global_reactives = NULL,
    local_reactives = NULL,
    reload = function(){
      if(is.reactivevalues(self$global_reactives)){
        self$global_reactives$force_refresh_all = Sys.time()
        self$global_reactives$has_data = Sys.time()
      }
    },
    finalize = function(){
      self$clean()
      logger(sprintf('[%s] Runtime Environment Removed.', private$module_env$module_id))
    },
    info = function(){
      cat('- wrapper environment -\n')
      cat(ls(self$wrapper_env))
      cat('\n- static environment -\n')
      cat(ls(self$static_env))
      cat('\n- param environment -\n')
      cat(ls(self$param_env))
      cat('\n- runtime environment -\n')
      cat(ls(self$runtime_env))
    },
    print = function(...){
      env_address(self)
    },
    clean = function(){
      # WARNING: this is not clean, but should be able to clear most of the large objects
      clear_env(self$parse_env)
      clear_env(self$param_env)
      clear_env(self$runtime_env)
      # clear_env(self$static_env)
      clear_env(private$cache_env)
    },
    initialize = function(session = getDefaultReactiveDomain(),
                          parent_env = NULL){
      private$session = session

      # parent_env should be an unlocked environment that can be active binded
      if(!is.environment(parent_env)){
        parent_env = new.env(parent = globalenv(), hash = T)
      }
      self$parent_env = parent_env

      # wrapper has all kind of util functions and it'll be sealed (locked)
      # One thing to notice that non of the functions within wrapper_env are
      # evaluated within itself. All are evaluated under "self", i.e. ExecEnvir
      # The reason why we use wrapper_env is because we don't want anyone to
      # change those functions as they are critical to modules.
      self$wrapper_env = new.env(parent = parent_env)

      # active bindings to data repository which allow us
      # the access to data loaded in data repo.
      rave_module_tools(self$wrapper_env)

      # static_env contains user self-defined functions. once initialized, they can
      # be read-only (in most of the cases).
      self$static_env = new.env(parent = self$wrapper_env)
      self$param_env = new.env(parent = self$static_env)
      self$param_env$..rave_future_env = new.env()

      # runtime_env, all variables will be stored within this environment, is the
      # one that real execute take place
      self$runtime_env = new.env(parent = self$param_env)
      self$static_env$..runtime_env = self$runtime_env
      self$static_env$.env = self$runtime_env
      self$static_env$..param_env = self$param_env

      # Environment for parsers. All source file will be parsed here
      # it can get access to runtime_env.
      # Old scheme was to parse src in static env and change function environment to
      # runtime_env, this is dangerous. So I come up with this solution
      self$parse_env = new.env(parent = self$runtime_env)


      private$cache_env = new.env()
      private$cache_env$.keys = c()
      self$ns = base::I

      bind_wrapper_env(self, self$wrapper_env)

      # self$wrapper_env$async_var = function(x, default = NULL){
      #   x_name = deparse(substitute(x))
      #   val = NULL
      #   future_env = self$param_env[['..rave_future_env']]
      #   if(is.environment(future_env) || is.list(future_env)){
      #     val = future_env[[x_name]]
      #
      #     if(!is.null(val)){
      #       return(val)
      #     }
      #   }
      #
      #   return(default)
      # }
      # self$wrapper_env$reloadUI = function(){
      #   self$reload()
      # }
      # self$wrapper_env$switch_to = function(module_id, varriable_name = NULL, value = NULL, quiet = F, ...){
      #   if(is.reactivevalues(self$global_reactives)){
      #     # if missing module_id, jump to last activated module
      #     # This is a hidden feature if not specifying module_id
      #     # 1. in the dev mode, I'll raise error if module_id is not string
      #     # 2. Be careful when using this hidden feature since it might cause infinite loop
      #     if(missing(module_id)){
      #       module_id = NULL
      #       hist = isolate(global_reactives$view_history)
      #       if(length(hist) > 1){
      #         ind = which(vapply(hist, '[[', logical(1L), 'activated'))
      #         if(length(ind)){
      #           ind = ind[length(ind)]
      #           module_id = hist[[ind]]$module_id
      #         }
      #       }
      #     }
      #     if(length(module_id)){
      #       self$global_reactives$switch_module = c(
      #         list(
      #           module_id = module_id,
      #           varriable_name = varriable_name,
      #           value = value,
      #           timestamp = Sys.time()
      #         ),
      #         list(...)
      #       )
      #     }else{
      #       showNotification(p('Cannot switch back. You have not opened any modules yet.'), type = 'warning')
      #     }
      #
      #
      #   }
      # }
      # self$wrapper_env$reload_module = function(){
      #   self$input_update(list(), init = TRUE)
      # }
      # self$wrapper_env$current_module = function(){
      #   if(is.reactivevalues(self$global_reactives)){
      #     return(isolate(get_val(self$global_reactives, 'execute_module', default = '')))
      #   }
      #   return('')
      # }
      # self$wrapper_env$rave_inputs = function(...){
      #   if(is.null(private$session)){
      #     rave_inputs(...)
      #   }else{
      #     self$rave_inputs(...)
      #   }
      # }
      # self$wrapper_env$rave_outputs = function(...){
      #   if(is.null(private$session)){
      #     rave_outputs(...)
      #   }else{
      #     self$rave_outputs(...)
      #   }
      # }
      # self$wrapper_env$rave_updates = function(...){
      #   if(is.null(private$session)){
      #     rave_updates(...)
      #   }else{
      #     self$rave_updates(...)
      #   }
      # }
      # self$wrapper_env$rave_execute = function(...){
      #   self$rave_execute(...)
      #   if(is.null(private$session)){
      #     rave_execute(...)
      #   }
      # }
      # self$wrapper_env$rave_checks = function(...){
      #   if(is.null(private$session)){
      #     rave_checks(...)
      #   }else{
      #     f = self$static_env[['rave_checks']]
      #     if(is.function(f)){
      #       f(...)
      #     }
      #   }
      # }
      # self$wrapper_env$cache = function(...){
      #   if(is.null(private$session)){
      #     cache(...)
      #   }else{
      #     self$cache(...)
      #   }
      # }
      # self$wrapper_env$cache_input = function(...){
      #   if(is.null(private$session)){
      #     cache_input(...)
      #   }else{
      #     self$cache_input(...)
      #   }
      # }
      # self$wrapper_env$rave_ignore = function(...){
      #   if(is.null(private$session)){
      #     rave_ignore(...)
      #   }
      # }
      # self$wrapper_env$get_brain = function(surfaces = 'pial', multiple_subject = FALSE){
      #   subject = get('subject', envir = rave::getDefaultDataRepository())
      #   brain = rave::rave_brain2(surfaces = surfaces, multiple_subject = multiple_subject)
      #   brain$load_electrodes(subject)
      #   brain$load_surfaces(subject)
      #   brain
      # }
      # self$wrapper_env$export_report = self$export_report
      # self$wrapper_env$rave_prepare = self$wrapper_env$rave_ignore # do nothing
      self$wrapper_env$source = function(file, local = T, ...){
        if(environmentIsLocked(self$static_env)){
          return()
        }

        # Try to use the file under the same dir
        dir = dirname(private$module_env$script_path)
        tmp_file = file.path(dir, file)
        if(file.exists(tmp_file)){
          logger('Try to source from [', tmp_file, ']')
          self$runtime_env$.__tmp_file = tmp_file
          eval(quote(base::source(.__tmp_file, local = T)), self$runtime_env)
        }else if(file.exists(file)){
          # logger('File [', tmp_file, '] does not exists, try to look for it.', level = 'INFO')
          self$runtime_env$.__tmp_file = file
          eval(quote(base::source(.__tmp_file, local = T)), self$runtime_env)
        }else{
          logger('File [', file, '] does not exists.', level = 'ERROR')
          return()
        }

        # Speed up
        # copy_env(self$parse_env, self$static_env, deep = F)
        list2env(as.list(self$runtime_env, all.names = T), envir = self$static_env)


      }

      # self$wrapper_env$require = function(package, ..., character.only = TRUE){
      #   p = as.character(substitute(package))
      #   if(!package_installed(p)){
      #     try({
      #       logger("Installing Package ", p, level = 'WARNING')
      #       install.packages(p, type = 'binary')
      #     })
      #   }
      #   do.call('require', args = c(list(
      #     package = p,
      #     character.only = TRUE
      #   ),
      #   list(...)))
      # }

      # self$wrapper_env$library = self$wrapper_env$require

      # self$wrapper_env$ns = function(id){
      #   self$ns(id)
      # }

      # advanced usage
      self$wrapper_env$getDefaultReactiveDomain = function(){
        id = private$module_env$module_id
        if(is.null(id) || !is(private$session, 'ShinySession')){
          stop('No module detected, please run "self$register_module(...)" to register module.')
        }
        private$session$makeScope(id)
      }

      self$wrapper_env$getDefaultReactiveInput = function(){
        session = self$wrapper_env$getDefaultReactiveDomain()
        input = NULL
        if(!is.null(session) && is(session, 'session_proxy')){
          input = session$input
        }else{
          stop('No module detected, please run "self$register_module(...)" to register module.')
        }
        return(input)
      }

      self$wrapper_env$getDefaultReactiveOutput = function(){
        session = self$wrapper_env$getDefaultReactiveDomain()
        output = NULL
        if(!is.null(session) && is(session, 'session_proxy')){
          output = session$output
        }else{
          stop('No module detected, please run "self$register_module(...)" to register module.')
        }
        return(output)
      }

      # Override observe, observeEvent
      # self$wrapper_env$observe = function(x, env = NULL, quoted = FALSE, priority = 0, domain = NULL, ...){
      #   if(!quoted){
      #     x = substitute(x)
      #   }
      #
      #   # Make sure shiny doesn't crash
      #   x = rlang::quo_squash(rlang::quo(
      #     tryCatch({
      #       shiny::withLogErrors({!!x})
      #     }, error = function(e){
      #       showNotification(htmltools::p(htmltools::strong('An error occurred'), htmltools::br(), 'Details: ',
      #                                     htmltools::span(as.character(e), style = 'font-style:italic;')), type = 'error')
      #     })
      #   ))
      #
      #
      #   if(!is.environment(env)){
      #     env = self$runtime_env
      #   }
      #   if(is.null(domain)){
      #     domain = self$wrapper_env$getDefaultReactiveDomain()
      #   }
      #   shiny::observe(
      #     x = x,
      #     env = env,
      #     quoted = T,
      #     priority = priority - 1L,
      #     domain = domain,
      #     ...
      #   )
      # }

      # self$wrapper_env$observeEvent = function(
      #   eventExpr, handlerExpr, event.env = NULL,
      #   event.quoted = FALSE, handler.env = NULL, handler.quoted = FALSE,
      #   priority = 0, domain = NULL, ...
      # ){
      #   if(!event.quoted){
      #     eventExpr = substitute(eventExpr)
      #   }
      #   if(!is.environment(event.env)){
      #     event.env = self$runtime_env
      #   }
      #
      #   if(!handler.quoted){
      #     handlerExpr = substitute(handlerExpr)
      #   }
      #   if(!is.environment(handler.env)){
      #     handler.env = self$runtime_env
      #   }
      #   if(is.null(domain)){
      #     domain = self$wrapper_env$getDefaultReactiveDomain()
      #   }
      #
      #   # Make sure shiny doesn't crash
      #   handlerExpr = rlang::quo_squash(rlang::quo(
      #     tryCatch({
      #       shiny::withLogErrors({!!handlerExpr})
      #     }, error = function(e){
      #       showNotification(htmltools::p(htmltools::strong('An error occurred'), htmltools::br(), 'Details: ',
      #                                     htmltools::span(as.character(e), style = 'font-style:italic;')), type = 'error')
      #     })
      #   ))
      #
      #   shiny::observeEvent(
      #     eventExpr = eventExpr, handlerExpr = handlerExpr, event.env = event.env,
      #     event.quoted = T, handler.env = handler.env, handler.quoted = T,
      #     priority = priority - 1L, domain = domain, ...
      #   )
      # }


      lockEnvironment(self$wrapper_env)

    },
    reset = function(inputs){
      if(shiny::is.reactivevalues(inputs)){
        inputs = shiny::isolate(shiny::reactiveValuesToList(inputs))
      }
      rm(list = ls(self$runtime_env), envir = self$runtime_env)
      for(nm in self$input_ids){
        assign(nm, inputs[[nm]], envir = self$runtime_env)
      }
    },
    copy = function(
      session_id = '__fake_runtime_env__', data_env = getDefaultDataRepository()
    ){
      # deep clone, but sharing the data, module environment
      fakesession = fake_session(rave_id = session_id)

      m = private$module_env
      new_exec = m$get_or_new_exec_env(
        parent_env = data_env, session = fakesession, new = T
      )

      # if(m$externalpackage){
      #   env = do.call("loadNamespace", list(package = "RAVEbeauchamplab"))
      #   if (!environmentIsLocked(new_exec$static_env)) {
      #     ..rdata_file = system.file("vars.RData", package = "RAVEbeauchamplab")
      #     base::load(file = ..rdata_file, envir = new_exec$static_env)
      #     lapply(names(as.list(env, all.names = T)), function(nm) {
      #       fun = env[[nm]]
      #       if (is.function(fun)) {
      #         environment(fun) = new_exec$runtime_env
      #       }
      #       new_exec$static_env[[nm]] = fun
      #     })
      #   }
      # }



      # migrate param_env
      list2env(as.list(self$param_env, all.names = T), new_exec$param_env)
      new_exec$private$module_env$load_script(session = fakesession)

      return(new_exec)
    },
    execute_with = function(param, async = FALSE, plan = NULL){
      lapply(names(param), function(nm){
        self$runtime_env[[nm]] = param[[nm]]
        self$param_env[[nm]] = param[[nm]]
      })
      res = self$execute(async = async)
      if(async){
        logger('Execute_with async not implemented.')
      }
      return(invisible(self$runtime_env))
    },
    export_report = function(expr, inputId = 'electrode', electrodes = NULL, async = F){
      .Deprecated('This function is deprecated', msg = 'Please avoid using this function in your module.')

      # assign('aaa', environment(), envir = globalenv())
      expr = substitute(expr)
      params = as.list(self$param_env)

      preload_info = get('preload_info', self$param_env)
      preload_electrodes = preload_info$electrodes
      reload = T
      if(!length(electrodes)){
        electrodes = preload_electrodes
        reload = F
      }else if(setequal(electrodes, preload_electrodes)){
        reload = F
      }

      new = self$copy()

      progress = progress('Exporting Report', max = length(electrodes))
      on.exit({progress$close()}, add = T)
      rave_data = getDefaultDataRepository()

      tryCatch({
        sid = rave_data$subject$id
        epoch_info = rave_data$.private$meta$epoch_info
        lapply_async(electrodes, function(e){
          if(reload){
            rave_prepare(
              subject = sid,
              electrodes = e,
              epoch = epoch_info$name,
              time_range = epoch_info$time_range,
              reference = rave_data$preload_info$reference_name,
              data_types = NULL,
              attach = F
            )
          }
          pm = params
          pm[[inputId]] = e
          new$execute_with(pm, async = async)
          eval(expr, envir = new$runtime_env)
        }, .call_back = function(i){
          progress$inc(sprintf('Calculating %d (%d of %d)', electrodes[i], i, length(electrodes)))
        }) ->
          fs
        return(fs)
      }, error = function(e){
        logger(str_c(capture.output({traceback(e)}), collapse = '\n'), level = 'ERROR')
        return(NULL)
      })
    },
    names = function(x){
      if(is.list(x)){
        nm = base::names(x)
        if(length(x) != length(nm) && is.null(nm)){
          nm = rep('', length(x))
        }
      }else{
        nm = base::names(x)
      }
      return(nm)
    },
    register_module = function(module_env){
      if(!is.null(private$module_env)){
        logger('Overriding Module Environment.', level = 'WARNING')
      }
      private$module_env = module_env
      self$ns = shiny::NS(module_env$module_id)

    },
    rave_inputs = function(..., .input_panels = list(), .tabsets = list(), .env = NULL){
      .tabsets = .input_panels
      names(.tabsets) = sapply(names(.input_panels), function(nm){
        s = str_trim(unlist(str_split(nm, '\\[|\\]')))
        s = s[s!='']
        s[length(s)]
      })


      .tabsetParams = lapply(names(.input_panels), function(nm){
        s = str_trim(unlist(str_split(nm, '\\[|\\]')))
        s = s[s!='']
        re = list(
          collapsed = '-' %in% s,
          headerColor = tryCatch({
            col = NULL
            tmp = s[str_detect(s, '^#')]
            if(length(tmp) == 1){
              col2rgb(tmp)
              col = tmp
            }
            col
          }, error = function(e){NULL})
        )
        re
      })
      names(.tabsetParams) = names(.tabsets)
      quos = rlang::quos(...)
      parsers = comp_parser()

      x = lapply(quos, parsers$parse_quo)
      names(x) = ids = sapply(x, function(comp){comp$inputId})

      if(!'Local Variables' %in% names(.tabsets)){
        rest_inputs = ids[!ids %in% unlist(.tabsets)]
        if(length(rest_inputs)){
          .tabsets[['Local Variables']] = c(rest_inputs)
        }
      }


      lapply(seq_along(.tabsets), function(ii){
        tabName = names(.tabsets)[ii]

        rlang::quo({
          do.call(box, args = c(
            list(width = 12,
                 title = !!tabName,
                 collapsible = T),
            !!.tabsetParams[[tabName]],
            !!lapply(.tabsets[[tabName]], function(inputIds){
              if(length(inputIds) == 1){
                comp = x[[inputIds]]
                return(comp$expr)
              }else{
                n = length(inputIds)
                mod2 = n %% 2
                mod3 = n %% 3
                if(mod3 == 0){
                  flex_basis = rep('flex-basis: 33%;', n)
                }else if(mod2 == 0){
                  flex_basis = rep('flex-basis: 50%;', n)
                }else if(mod3 == 1){
                  flex_basis = rep('flex-basis: 50%;', n)
                  flex_basis[length(flex_basis)] = 'flex-basis: 100%;'
                }else{
                  flex_basis = rep('flex-basis: 33%;', n)
                  flex_basis[length(flex_basis) - c(0:1)] = 'flex-basis: 50%;'
                }

                return(rlang::quo(
                  do.call(div, args = c(
                    list(class = 'rave-grid-inputs'),
                    !!lapply(seq_len(n), function(jj){
                      inputId = inputIds[[jj]]
                      rlang::quo(
                        do.call(div, args = c(
                          list(style = !!flex_basis[[jj]], !!x[[inputId]]$expr)
                        ))
                      )
                    })
                  ))
                ))
              }
            })
          ))

        })

      }) ->
        ui_inputs

      rlang::quo({
        do.call(shiny::fluidRow, args = !!ui_inputs)
      }) -> ui_inputs

      private$inputs = list(
        quos = ui_inputs,
        comp = x
      )

      self$register_input_events = function(input, output, session, local_data){
        lapply(x, function(comp){
          comp$observers(input, output, session, local_data, self)
        })
      }

      invisible()
    },
    rave_outputs = function(..., .output_tabsets = list(), .tabsets = list(), .env = NULL){
      .tabsets = .output_tabsets
      quos = rlang::quos(...)
      assert_that(length(quos) > 0, msg = 'No output defined!')
      parsers = comp_parser()
      x = lapply(names(quos), function(nm){
        re = parsers$parse_quo(quos[[nm]])
        re$label = nm
        re
      })

      ids = sapply(x, function(comp){comp$outputId})
      names(x) = ids

      #### Generate UIs for output

      # 1. tabsets in .tabsets
      widths = .tabsets[['width']]
      .tabsets[['width']] = NULL

      if(length(.tabsets)){
        names = names(.tabsets)
        ntabs = length(names)
        if(length(widths) < ntabs){
          widths = rep(widths, ntabs)
        }

        lapply(seq_len(ntabs), function(ii){
          nm = names[[ii]]
          ids = .tabsets[[nm]]

          quo_panels = lapply(seq_along(ids), function(ii){
            comp = ids[ii]
            title = names(comp)
            rlang::quo({
              shiny::tabPanel(
                title = !!title,
                div(
                  class = 'rave-abs-right',
                  div(
                    class = 'btn btn-box-tool force-recalculate',
                    shiny::icon('refresh')
                  ),
                  div_elastic(css_selector = '.tab-pane')
                ),
                do.call(shiny::fluidRow, args = !!{lapply(comp[[1]], function(output_id){
                  comp = x[[output_id]]
                  width = comp[['width']]; width %?<-% 12L
                  expr = quote(shiny::column())
                  expr = c(as.list(expr), list(
                    shiny::h4(comp$label),
                    comp$expr,
                    width = width
                  ))
                  as.call(expr)
                })}
                )
              )
            })
          })

          quo_box = rlang::quo({
            do.call(shinydashboard::tabBox,
                    args = c(
                      list(title = !!nm, width = !!widths[[ii]]),
                      !!quo_panels
                    )
            )
          })

          quo_box
        }) ->
          tab_boxes
      }else{
        tab_boxes = NULL
      }

      left_ids = ids[!ids %in% unlist(.tabsets)]

      lapply(left_ids, function(nm){
        comp = x[[nm]]
        width = comp$width; width %?<-% 12L
        rlang::quo({
          expand_box(
            width = width,
            title = comp$label,
            collapsible = T,
            !!comp$expr
          )
        })
      }) ->
        single_boxes

      ui_comps = rlang::quo(do.call(shiny::fluidRow, args = c(!!tab_boxes, !!single_boxes)))

      #### Reactive functions
      private$outputs = list(
        quos = ui_comps,
        comp = x
      )
      self$register_output_events = function(input, output, session, local_data){
        lapply(x, function(comp){
          comp$observers(input, output, session, local_data, self)
        })
      }
    },
    rave_updates = function(..., .env = NULL){
      quos = rlang::quos(...)
      private$update = quos

      self$input_update = function(input, session = NULL, init = FALSE){
        start = Sys.time()
        input = dropNulls(input)
        if(!init){
          # Deprecated, do nothing
          return(invisible())
        }
        if(is.null(session)){
          session = getDefaultReactiveDomain() #private$session
        }
        var_names = names(private$update)
        n_errors = c(0,0)
        envir = environment()
        errors = NULL
        # passed = TRUE
        for(quo in private$update[var_names == '']){
          tryCatch({
            eval_dirty( quo, env = self$param_env )
          },error = function(e){
            logger('Error in updating input (initialization)', level = 'ERROR')
            s = capture.output(traceback(e))
            lapply(s, logger, level = 'ERROR')
            envir$n_errors[1] = envir$n_errors[1] + 1
            envir$errors = c(envir$errors, as.character(e))
            # envir$passed = FALSE
          })

          # if(!passed){
          #   break();
          # }
        }



        for(varname in var_names[var_names != '']){
          # if(!passed){
          #   break;
          # }
          tryCatch({
            comp = private$inputs$comp[[varname]]
            if(is.null(comp)){
              return()
            }
            new_args = eval_dirty(
              private$update[[varname]], data = input, env = self$param_env
            )

            comp$updates(session = session, .args = new_args)
          },error = function(e){
            logger('Error in updating input ', varname, level = 'ERROR')
            s = capture.output(traceback(e))
            lapply(s, logger, level = 'ERROR')
            envir$n_errors[2] = envir$n_errors[2] + 1
            envir$passed = FALSE
          })
        }


        end = Sys.time()
        delta = time_diff(start, end)
        logger(sprintf('Updating inputs takes %.2f %s. Total errors: %d + %d', delta$delta, delta$units, n_errors[1], n_errors[2]))


        # Activate this module if no error occurred during input-update phase
        hist_len = isolate(length(self$global_reactives$view_history))
        if(length(hist_len)){
          if(sum(n_errors)){
            global_reactives$view_history[[hist_len]]$activated = FALSE
          }else{
            global_reactives$view_history[[hist_len]]$activated = TRUE
          }
        }


        return(list(
          n_errors = n_errors,
          init_error_msgs = errors
        ))
      }
      invisible()
    },
    rave_execute = function(..., auto = TRUE, .env = NULL, async_vars = NULL){
      quos = rlang::quos_auto_name(rlang::quos(...))

      normal_quos = quos[!names(quos) %in% 'async']
      private$executes = c(private$executes, normal_quos)
      async_quo = quos[['async']]
      self$async_module = !is.null(async_quo)
      self$auto_execute = auto

      self$execute = function(async = FALSE, force = FALSE){
        if(!force && !self$auto_execute){
          return()
        }
        self$runtime_env$.is_async = async
        async_future = NULL

        if(async){
          if(self$async_module){
            async_env = new.env(parent = self$runtime_env)
            async_env[['..async_quo']] = async_quo
            async_env[['..async_var']] = async_vars

            packages = str_match(search(), '^package:(.+)$')[,2]; packages = packages[!is.na(packages)]
            packages = unique(packages, private$module_env$packages)

            self$param_env$..rave_future_obj =
              future::future({
                eval_dirty(..async_quo)#, env = async_env)
                if(is.null(..async_var)){
                  return(environment())
                }else{
                  re = sapply(..async_var, get0, simplify = F, USE.NAMES = T)
                  re
                }
              }, packages = packages, evaluator = future::multiprocess, envir = async_env,
              gc = FALSE)
          }
        }else{
          if(length(private$executes)){
            lapply(private$executes, eval_dirty, env = self$runtime_env)
          }
        }

        return(self$param_env[['..rave_future_obj']])
      }
    },
    clear_cache = function(){
      env = private$cache_env
      nms = names(env)
      nms = nms[! nms %in% c('.keys', env[['.keys']])]
      if(length(nms)){
        rm(list = nms, envir = env)
      }
    },
    cache = function(key, val, global = FALSE, replace = FALSE,
                     session = getDefaultReactiveDomain(), persist = FALSE){
      digest = as.character(digest::digest(key))
      if(global){
        env = getDefaultCacheEnvironment(session = session)
      }else{
        env = private$cache_env
      }
      if(!replace){
        if(exists(digest, envir = env, inherits = FALSE)){
          return( env[[digest]] )
        }
        # else{
        #   cat('register keeey ', key)
        # }
        if(exists(digest, envir = private$cache_env, inherits = FALSE)){
          return( private$cache_env[[digest]] )
        }
      }
      if(missing(val)){
        return(NULL)
      }

      # save cache
      env[[digest]] = shiny::isolate(val)

      if(persist){
        env$.keys = unique(c(env$.keys, digest))
      }

      return(val)
    },
    cache_input = function(inputId, val = NULL, read_only = TRUE, sig = NULL){

      sig %?<-% add_to_session(private$session)
      is_global = self$is_global(inputId)

      key = list(
        type = '.rave-inputs-Dipterix',
        inputId = inputId,
        sig = sig
      )
      if(read_only){
        v = self$cache(key, global = is_global, replace = FALSE, persist = TRUE)
        v %?<-% val
      }else{
        v = self$cache(key, val, global = is_global, replace = TRUE, persist = TRUE)
      }
      # logger(inputId, ' - ', paste(deparse(v), collapse = ''))

      return(v)
    },
    set_browser = function(expr){

      current_key = add_to_session(private$session)

      children_keys = add_to_session(session, 'rave_linked_by', NULL)
      children_keys = children_keys[!children_keys %in% current_key]
      # children_keys = unique(c(current_key, children_keys))

      module_id = private$module_env$module_id

      lapply(children_keys, function(storage_key){
        private$session$sendCustomMessage('rave_set_storage', list(
          module_id = module_id,
          expr = expr,
          storage_key = storage_key,
          current_key = current_key
        ))
      })

    },
    generate_input_ui = function(sidebar_width = 3L){
      ns = self$ns
      # TODO change it to package environment, otherwise customized package code won't work like `get_palette`
      # env = environment()

      more_btns = list(
        # vignette = tags$li(actionLink(self$ns('..vignette'), 'Show Module Description')),
        async = tags$li(actionLink(self$ns('..async_run'), 'Run Algorithm (Async)')),
        export = tags$li(actionLink(self$ns('..incubator'), 'Exports'))
      )

      # exports
      export_func = names(as.list(self$static_env))
      is_export_func = vapply(export_func, function(x){
        is.function(self$static_env[[x]]) && str_detect(x, 'export_')
      }, FUN.VALUE = logical(1))
      if(length(is_export_func) == 0 || sum(is_export_func) == 0){
        more_btns[['export']] = NULL
      }

      # Async
      if(!self$async_module){
        more_btns[['async']] = NULL
      }


      if(length(more_btns)){
        names(more_btns) = NULL
        more_ui = box(
          title = 'More...',
          collapsed = T,
          tags$ul(
            class = 'rave-grid-inputs',
            tagList(more_btns)
          ),
          width = 12,
          collapsible = T
        )
      }else{
        more_ui = NULL
      }


      if(sidebar_width == 0){
        sidebar_width = '3 hidden';
      }

      div(
        class = sprintf('col-sm-%s rave-input-panel', sidebar_width),
        # eval_dirty(private$inputs$quos, env = new.env(), data = self$parent_env),
        rlang::eval_tidy(private$inputs$quos, data = as.list(self$parent_env)),
        fluidRow(
          uiOutput(self$ns('..params_current')),
          more_ui
        )
      )
    },
    generate_output_ui = function(sidebar_width = 3L){
      ns = self$ns
      # env = environment()
      div(
        class = sprintf('col-sm-%d rave-output-panel', 12L - sidebar_width),
        # eval_dirty(private$outputs$quos, env = new.env(), data = self$parent_env)
        rlang::eval_tidy(private$outputs$quos, data = as.list(self$parent_env))
      )

    },
    is_global = function(inputId){
      tabsets = private$tabsets
      if(length(tabsets) == 0){
        return(FALSE)
      }
      nms = names(tabsets)
      ts = unlist(tabsets[str_detect(str_to_lower(nms), 'global')])
      if(length(ts) == 0){
        return(FALSE)
      }
      return(inputId %in% ts)
    }
  ),
  active = list(
    input_ids = function(){
      names(private$inputs$comp)
    },
    input_labels = function(){
      re = lapply(private$inputs$comp, function(x){x$args$label})
      names(re) = names(private$inputs$comp)
      return(re)
    },
    output_labels = function(){
      re = lapply(private$outputs$comp, function(x){x$label})
      names(re) = names(private$outputs$comp)
      return(re)
    },
    output_ids = function(){
      names(private$outputs$comp)
    }
  )
)
