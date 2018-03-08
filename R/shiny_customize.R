

#' @export
compoundInput <- function(
  inputId, label = '', components = NULL, max_ncomp = 10, inital_ncomp = 1
){
  value <- deparse(substitute(components))
  dots = lazyeval::as.lazy(value)
  dots = lazyeval::as.lazy_dots(as.list(dots$expr[-1]))
  lapply(dots, parse_call, env = parent.frame()) ->
    dots
  class(dots) <- 'lazy_dots'

  inital_ncomp = max(inital_ncomp, 1)


  div(
    id = inputId,
    class = 'rave-ui rave-ui-compound',
    'data-value' = inital_ncomp,
    'data-max' = max_ncomp,
    div(
      class = 'rave-ui-compound-wrapper',
      tagList(
        lapply(seq(1, max_ncomp), function(ind){
          div(
            class = paste('rave-ui-compound-inner', ifelse(inital_ncomp < ind, 'hidden', '')),
            'data-value' = ind,
            tagList(
              lapply(dots, function(comp){
                comp = comp$.change_param(
                  inputId = paste0(inputId, '_', comp$.args$inputId, '_', ind),
                  label = paste0(label, '-', comp$.args$label, ' ', ind)
                )
                lazyeval::lazy_eval(comp)
              })
            )
          )
        })
      )
    ),
    div(
      class = 'rave-ui-compound-ctrl',
      tags$button(class = 'btn btn-default', type = 'button', 'data-target' = inputId, 'data-value'='1', '+'),
      tags$button(class = 'btn btn-default', type = 'button', 'data-target' = inputId, 'data-value'='0', '-')
    ),
    div(
      class = 'rave-ui-compound-meta hidden',
      paste(
        '{',
        paste(
          sapply(dots, function(comp){
            sprintf('"%s":"%s::%s"',
                    comp$.args$inputId,
                    comp$.func$func_ns,
                    comp$.func$func_name)
          }),
          collapse = ','
        ),
        '}'
      )

    )
  )

}

fake_session <- function(rave_id = '__fake_session__'){
  fakesession = new.env()
  fakesession$sendInputMessage = function(inputId, message){
    return(message)
  }
  fakesession$userData = new.env(parent = emptyenv())
  fakesession$userData$rave_id = rave_id
  fakesession
}


with_fake_session <- function(func, ...){
  fakesession = new.env()
  fakesession$sendInputMessage = function(inputId, message){
    return(message)
  }
  local({
    func(fakesession, ...)
  }, envir = fakesession)
}

get_fake_updated_message <- function(..., .args = list(), .func = NULL){
  .args = c(
    list(...),
    .args
  )
  .args = dropNulls(.args)
  if(sum(names(.args) %in% c('choices', 'selected')) > 0){
    .func = shiny::updateSelectInput
  }

  if(is.function(.func)){
    .args = c(
      func = .func,
      .args
    )
    return(do.call(with_fake_session, args = .args))
  }else{
    return(.args)
  }
}


#' @export
updateCompoundInput <- function(session, inputId, initialize, value = NULL, which = 1:100, ...){
  values = initialize
  excl = NULL
  if(length(value)){
    for(ii in 1:length(value)){
      excl = c(excl, ii)
      val = value[[ii]]
      values_cp = values
      for(nm in names(val)){
        tmp = values_cp[[nm]]
        if(is.null(tmp)){
          values_cp[[nm]] = list(value = val[[nm]])
        }else{
          tmp_l = val[nm]
          if(sum(c('choices', 'selected') %in% names(tmp)) > 0){
            names(tmp_l) = 'selected'
          }else{
            names(tmp_l) = 'value'
          }
          values_cp[[nm]] = c(
            values_cp[[nm]],
            tmp_l
          )
        }
      }

      lapply(values_cp, function(v){
        v = get_fake_updated_message(.args = v)
        return(v)
      }) -> values_cp

      message = force(dropNulls(list(value = values_cp, which = ii)))
      session$sendInputMessage(inputId, message)
    }
  }

  which = which[!which %in% excl]
  if(length(which)){
    lapply(values, function(v){
      v = get_fake_updated_message(.args = v)
      return(v)
    }) -> values_cp
    message = force(dropNulls(list(value = values_cp, which = which)))
    session$sendInputMessage(inputId, message)
  }
  return(invisible())

}

.ui_update_repo <- new.env()


ui_register_function <- function(key, update_func = NULL, value_field = 'value', update_value = F, default_args = list()){
  if(!is.null(update_func) && is.function(update_func)){
    update_func = list(
      update_func = update_func,
      value = value_field,
      default_args = default_args,
      update_value = update_value
    )
    assign(key, update_func, envir = .ui_update_repo)
  }else{
    update_func = get(key, envir = .ui_update_repo)
  }
  assertthat::assert_that(is.function(update_func$update_func), msg = 'Update function not found!')
  return(invisible(update_func))
}





# re = compoundInput(
#   'asdid','label',
#   shiny::textInput('textid', 'label1'),
#   selectInput('groupid', 'Group', choices = ''),max_ncomp = 3
# )
#
# js = readLines('./inst/assets/input_compound.js')
#
# shinyApp(
#   ui = fluidPage(
#     fluidRow(
#       singleton(tags$head(tags$script(HTML(js)))),
#       column(3,re$ui(), actionButton('a','click')),
#       column(5,
#              verbatimTextOutput('oo')
#       ))
#   ),
#   server=function(input, output, session){
#     output$oo <- renderPrint({
#       print(input$asdid)
#     })
#
#     observeEvent(input$a, {
#       updateCompoundInput(session, 'asdid', value = list(
#         groupid = list(
#           choices = letters[1:10]
#         )
#       ))
#     })
#   }
# )


