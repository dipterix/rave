
.onAttach <- function(libname, pkgname){

  # For production
  cran_pkgs = c('pryr', 'assertthat', 'lazyeval', 'shinydashboard', 'fftw', 'yaml',
                'fftwtools', 'plotly', 'digest', 'gridBase', 'shinyjs', 'ff',
                'devtools', 'rlang', 'V8')

  cran_pkgs = cran_pkgs[!cran_pkgs %in% utils::installed.packages()[,1]]
  if(length(cran_pkgs)){
    message("Installing Dependencies from CRAN...")
    install.packages(cran_pkgs, repos='http://cran.us.r-project.org')
  }

  # if(!'promises' %in% utils::installed.packages()[,1]){
  #   message("Installing Dependencies from GITHUB [rstudio/promises]")
  #   devtools::install_github("rstudio/promises")
  # }

  # check shiny 1.1 installed
  # if(utils::packageVersion('shiny') < as.package_version('1.0.5.9000')){
  #   message("Installing Dependencies from GITHUB [rstudio/shiny@async]")
  #   devtools::install_github("rstudio/shiny@async")
  # }

  bioc_pkgs = c('HDF5Array', 'rhdf5')
  bioc_pkgs = bioc_pkgs[!bioc_pkgs %in% utils::installed.packages()[,1]]
  if(length(bioc_pkgs)){
    message("Installing Dependencies from BIOCONDUCTOR...")
    source("https://bioconductor.org/biocLite.R")
    biocLite(bioc_pkgs, suppressUpdates = T, suppressAutoUpdate = T)
  }

  shiny::registerInputHandler("rave.compoundInput", function(data, shinysession, name) {
    if (is.null(data)){
      return(NULL)
    }

    # restoreInput(id = , NULL)
    meta = as.list(data$meta)
    timeStamp = as.character(data$timeStamp)
    maxcomp = as.integer(data$maxcomp)
    inputId = as.character(data$inputId)
    value =  data$val


    ids = names(meta)
    ncomp = as.integer(data$ncomp)
    if(length(ids) == 0 || is.null(ncomp) || ncomp <= 0){
      return(NULL)
    }

    nvalid = length(dropInvalid(value, deep = T))
    nvalid = max(1, nvalid)
    nvalid = min(nvalid, ncomp)

    re = value[1:nvalid]

    attr(re, 'ncomp') <- ncomp
    attr(re, 'meta') <- meta
    attr(re, 'timeStamp') <- timeStamp
    attr(re, 'maxcomp') <- maxcomp
    return(re)

  }, force = TRUE)


  ui_register_function('shiny::textInput', shiny::updateTextInput)
  ui_register_function('shiny::selectInput', shiny::updateSelectInput, value_field = 'selected')
  ui_register_function('shiny::numericInput', shiny::updateNumericInput)
  ui_register_function('shiny::sliderInput', shiny::updateSliderInput)
  ui_register_function('shiny::checkboxInput', shiny::updateCheckboxInput)
  ui_register_function('shiny::textAreaInput', shiny::updateTextAreaInput)
  ui_register_function('shiny::dateInput', shiny::updateDateInput)
  ui_register_function('shiny::dateRangeInput', shiny::updateDateRangeInput)
  ui_register_function('shiny::checkboxGroupInput', shiny::updateDateInput, value_field = 'selected')
  ui_register_function('rave::compoundInput', rave:::updateCompoundInput, update_value = T)

  ui_register_function('shiny::plotOutput', shiny::renderPlot, default_args = list(res = 72))
  ui_register_function('shiny::tableOutput', shiny::renderTable)
  ui_register_function('shiny::verbatimTextOutput', shiny::renderPrint)
  ui_register_function('shiny::dataTableOutput', shiny::renderDataTable)
  ui_register_function('plotly::plotlyOutput', plotly::renderPlotly)
  ui_register_function('shiny::uiOutput', shiny::renderUI)
  ui_register_function('shiny::imageOutput', shiny::renderImage, default_args = list(deleteFile = FALSE))
  ui_register_function('shiny::htmlOutput', shiny::renderText)
  ui_register_function('shiny::textOutput', shiny::renderText)
  rave::rave_setup()



  # For dev:
  dev_log = c(
    '0. [Finished] Added version check',
    '1. [Finished] Remembers and restore the global inputs',
    '      a. [Finished] Cache inputs and overrides when re-init modules',
    '      b. [Finished] Fix updateCompountInput',
    '      c. [Finished] When switch to other modules, update globals',
    '            I.   [Finished] Re-write cache function',
    '            II.  [Finished] Expose fake cache_input',
    '            III. [Aborted] Inplement interactive inputs',
    '2. [Finished] On session ended, clean up memory.',
    '3a. [Finished] (buggy) Export as reports',
    '3b. SUMA export',
    '4. [Finished] Import modules as RMD files.',
    '5. Support data types: power? phase?',
    '6. [Partial] Do per elecctrodes'
  )
  fins = stringr::str_detect(dev_log, '\\[Finished\\]')
  parts = stringr::str_detect(dev_log, '\\[Partial\\]')
  abrts = stringr::str_detect(dev_log, '\\[Aborted\\]')
  dev_log[fins] = crayon::green(dev_log[fins])
  dev_log[parts] = crayon::bgYellow(dev_log[parts])
  dev_log[abrts] = crayon::silver(dev_log[abrts])
  dev_log[!(fins | parts | abrts)] = crayon::bgRed(dev_log[!(fins | parts | abrts)])
  cat('TODO list - ', dev_log, '\nGithub - @rave-Dipterix', sep = '\n')

  is_dev = exists('..rave__dev..', envir = globalenv(), inherits = F)
  ver = as.character(utils::packageVersion('rave'))
  cat('\nrave -', ver)
  last_ver = rave::rave_hist$get_or_save('..last_ver..')
  if(is.null(last_ver) || utils::compareVersion(last_ver, as.character(ver)) < 0 || is_dev){
    cat('\n  Making some changes...\n')
    .mf = '../module_dev.csv'
    if(file.exists(.mf) && !is_dev){
      .mf = tools::file_path_as_absolute(.mf)
    }else{
      if(is_dev){
        .mf = NULL
      }else{
        .mf = rave::rave_opts$get_options('module_lookup_file')
      }
      if(is.null(.mf) || !file.exists(.mf)){
        .mf = '~/rave_modules/modules.csv'
        dir.create('~/rave_modules/', showWarnings = F, recursive = T)
        writeLines(
          readLines(system.file('modules.csv', package = 'rave')),
          .mf)
      }
      if(is_dev){
        writeLines(
          readLines(system.file('modules.csv', package = 'rave')),
          .mf)
      }
      module_lookup_file = .mf
      module_dir = dirname(module_lookup_file)

      file.copy(system.file('modules', package = 'rave'),
                module_dir, recursive = T, overwrite = T)

    }
    rave::rave_opts$set_options(
      module_lookup_file = .mf,
      delay_input = 20,
      max_worker = parallel::detectCores() - 1
    )
    rave::rave_opts$save_settings()
    rave::rave_hist$save(`..last_ver..` = ver)
  }
}

