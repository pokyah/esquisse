
#' Module to display the code of the chart and export it
#'
#' @param id Module's id
#'
#' @return A ui definition
#' @noRd
#'
#' @importFrom htmltools tags tagList
#' @importFrom shiny actionLink NS icon reactiveValuesToList
#'
moduleCodeUI <- function(id) {

  ns <- shiny::NS(id)

  htmltools::tagList(
    tags$button(
      class = "btn btn-default btn-xs pull-right btn-copy-code",
      "Copy to clipboard", `data-clipboard-target` = "#codeggplot"# onclick = "ClipBoard()"
    ), htmltools::tags$script("new Clipboard('.btn-copy-code');"),
    htmltools::tags$br(),
    htmltools::tags$b("Code:"),
    shiny::uiOutput(outputId = ns("code")),
    htmltools::tags$textarea(id = "holderCode", style = "display: none;"),
    shiny::actionLink(inputId = ns("insert_code"), label = "Insert code in script", icon = shiny::icon("arrow-circle-left")),
    htmltools::tags$br()#,
    # htmltools::tags$script(src = "esquisse/copy-clipboard.js")
  )

}

#' Module to display the code of the chart and export it
#'
#' @param input   standard \code{shiny} input.
#' @param output  standard \code{shiny} output.
#' @param session standard \code{shiny} session.
#' @param varSelected Result of the module dragAndDrop.
#' @param dataChart Result of the module chooseData.
#' @param paramsChart Result of modul chartControls.
#'
#' @return none
#' @noRd
#'
#' @importFrom htmltools tags tagList
#' @importFrom shiny reactive renderUI observeEvent
#' @importFrom rstudioapi insertText getActiveDocumentContext
#'
moduleCodeServer <- function(input, output, session, varSelected, dataChart, paramsChart, geomSelected) {

  ns <- session$ns

  codegg <- shiny::reactive({
    code_geom <- guess_geom(
      xtype = if (!is.null(varSelected$x$xvar)) col_type(dataChart$x[[varSelected$x$xvar]]),
      ytype = if (!is.null(varSelected$x$yvar)) col_type(dataChart$x[[varSelected$x$yvar]]),
      type = geomSelected$x
    )
    code_aes <- guess_aes(
      x = varSelected$x$xvar,
      y = varSelected$x$yvar,
      fill = varSelected$x$fill,
      color = varSelected$x$color,
      size = varSelected$x$size,
      geom = code_geom,
      xtype = if (!is.null(varSelected$x$xvar)) col_type(dataChart$x[[varSelected$x$xvar]]),
      ytype = if (!is.null(varSelected$x$yvar)) col_type(dataChart$x[[varSelected$x$yvar]])
    )
    code_aes <- lapply(
      X = code_aes,
      FUN = function(x) {
        as.character(x)[-1]
      }
    )

    params_chart <- shiny::reactiveValuesToList(paramsChart)

    args_geom <- list()
    if (code_geom == "histogram") {
      args_geom$bins <- params_chart$bins
    }
    if (code_geom == "density") {
      args_geom$adjust <- params_chart$adjust
    }
    
    if (code_geom %in% c("bar", "histogram", "boxplot", "density") & is.null(varSelected$x$fill)) {
      args_geom$fill <- paramsChart$fill_color %||% "#0C4C8A"
    }
    
    if (code_geom %in% c("line", "point") & is.null(varSelected$x$color)) {
      args_geom$color <- paramsChart$fill_color %||% "#0C4C8A"
    }
    
    if (code_geom %in% c("bar")) {
      args_geom$position <- paramsChart$position %||% "dodge"
      if (args_geom$position == "stack")
        args_geom$position <- NULL
    }
    
    # Coord
    if (isTRUE(paramsChart$flip)) {
      coord <- "flip"
    } else {
      coord <- NULL
    }
    
    # Scales
    if (!is.null(varSelected$x$fill)) {
      filltype <- col_type(dataChart$x[[varSelected$x$fill]])
    } else {
      filltype <- NULL
    }
    if (!is.null(varSelected$x$color)) {
      colortype <- col_type(dataChart$x[[varSelected$x$color]])
    } else {
      colortype <- NULL
    }
    code_scale <- get_code_scale(
      fill = varSelected$x$fill, color = varSelected$x$color,
      params = paramsChart, filltype = filltype, colortype = colortype
    )

    code <- ggcode(
      data = dataChart$name,
      aes = code_aes,
      geom = code_geom,
      scale = code_scale,
      args_geom = args_geom,
      theme = paramsChart$theme, coord = coord,
      labs = params_chart[c("title", "x", "y", "caption", "subtitle")],
      params = params_chart
    )
    return(code)
  })


  shiny::observeEvent(input$insert_code, {
    context <- rstudioapi::getActiveDocumentContext()
    code <- codegg()
    if (input$insert_code == 1) {
      code <- paste("library(ggplot2)", code, sep = "\n\n")
    }
    rstudioapi::insertText(text = code, id = context$id)
  })

  output$code <- shiny::renderUI({
    htmltools::tagList(
      rCodeContainer(id = "codeggplot", codegg())#,
      # htmltools::tags$button(
      #   class="btn btn-clipboard", "Copy", `data-clipboard-target`="#code_ggplot"
      # ),
      # htmltools::tags$script("new Clipboard('btn-clipboard');")
    )
  })

}





get_code_scale <- function(fill = NULL, color = NULL, params = list(), filltype = NULL, colortype = NULL) {
  # scale_fill
  params_scale_fill <- NULL
  if (!is.null(fill)) {
    if (!is.null(params$palette)) {
      if (params$palette == "ggplot2") {
        # if (filltype == "categorical") {
        #   params_scale_fill <- "scale_fill_hue()"
        # } else {
        #   params_scale_fill <-" scale_fill_gradient()"
        # }
        params_scale_fill <- NULL
      } else {
        if (filltype == "categorical") {
          params_scale_fill <- sprintf("scale_fill_brewer(palette = \"%s\")", params$palette)
        } else {
          params_scale_fill <- sprintf("scale_fill_distiller(palette = \"%s\")", params$palette)
        }
      }
    }
  }
  # scale color
  params_scale_color <- NULL
  if (!is.null(color)) {
    if (!is.null(params$palette)) {
      if (params$palette == "ggplot2") {
        # if (colortype == "categorical") {
        #   params_scale_color <- "scale_color_hue()"
        # } else {
        #   params_scale_color <- "scale_color_gradient()"
        # }
        params_scale_color <- NULL
      } else {
        if (colortype == "categorical") {
          params_scale_color <- sprintf("scale_color_brewer(palette = \"%s\")", params$palette)
        } else {
          params_scale_color <- sprintf("scale_color_distiller(palette = \"%s\")", params$palette)
        }
      }
    }
  }
  # list(scale_fill = params_scale_fill, scale_color = params_scale_color)
  if (!is.null(params_scale_fill) | !is.null(params_scale_color)) {
    paste(c(params_scale_fill, params_scale_color), collapse = " +\n")
  } else {
    NULL
  }
}
















