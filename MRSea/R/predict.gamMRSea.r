#' Function for making predictions for a model containing a CReSS basis (two dimensional local smooth).
#'
#' This function calculates vector of predictions on the scale of the response or link.
#'
#' @param predict.data Data frame of covariate values to make predictions to
#' @param g2k Matrix of distances between prediction locations and knot locations (n x k). May be Euclidean or geodesic distances.
#' @param model Object from a GEE or GLM model
#' @param type Type of predictions required. (default=`response`, may also use `link`).
#' @param coeff Vector of coefficients (default = NULL). To be used when bootstrapping and sampling coefficients from a distribution e.g. in \code{do.bootstrap.cress}.
#'
#' @details
#' Calculate predictions for a model whilst centering the CReSS bases in the same way as the fitted model. Note, if there is an offset in the model it must be called 'area'.
#'
#' @return
#' Returns a vector of predictions on either the response or link scale
#'
#' @examples
#'
#' # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' # offshore redistribution data
#' # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' data(dis.data.re)
#' data(predict.data.re)
#' data(knotgrid.off)

#' # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' # distance sampling
#' dis.data.re$survey.id<-paste(dis.data.re$season,dis.data.re$impact,sep="")
#' result<-ddf(dsmodel=~mcds(key="hn", formula=~1), data=dis.data.re, method="ds",
#'         meta.data=list(width=250))
#' dis.data.re<-create.NHAT(dis.data.re,result)
#' count.data<-create.count.data(dis.data.re)
#'
#' # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#' # spatial modelling
#' splineParams<-makesplineParams(data=count.data, varlist=c('depth'))
#' #set some input info for SALSA
#' count.data$response<- count.data$NHAT
#' # make distance matrices for datatoknots and knottoknots
#' distMats<-makeDists(cbind(count.data$x.pos, count.data$y.pos), na.omit(knotgrid.off))
#' # choose sequence of radii
#' r_seq<-getRadiiChoices(8,distMats$dataDist)
#' # set initial model without the spatial term
#' initialModel<- glm(response ~ as.factor(season) + as.factor(impact) + offset(log(area)),
#'                 family='quasipoisson', data=count.data)
#' # make parameter set for running salsa2d
#' salsa2dlist<-list(fitnessMeasure = 'QICb', knotgrid = knotgrid.off, 
#'                  knotdim=c(26,14), startKnots=4, minKnots=4,
#'                  maxKnots=20, r_seq=r_seq, gap=4000, interactionTerm="as.factor(impact)")
#' salsa2dOutput_k6<-runSALSA2D(initialModel, salsa2dlist, d2k=distMats$dataDist,
#'                    k2k=distMats$knotDist, splineParams=splineParams)
#'
#'
#' # make predictions on response scale
#' preds<-predict.gamMRSea(predict.data.re, dists, salsa2dOutput_k6$bestModel)
#'
#' @export
#'
predict.gamMRSea<- function (predict.data, g2k=NULL, model, type = "response",coeff = NULL)
{
  # attributes(model$formula)$.Environment <- environment()
  # radii <- splineParams[[1]]$radii
  # radiusIndices <- splineParams[[1]]$radiusIndices
  # dists <- g2k
  
  splineParams<- model$splineParams
  
  require(splines)
  x2 <- data.frame(response = rpois(nrow(predict.data), lambda = 5),
                   predict.data)
  tt <- terms(model)
  Terms <- delete.response(tt)
  
  if(!is.null(g2k)){
    splineParams[[1]]$dist<-g2k
  }
  
  m <- model.frame.gamMRSea(Terms, predict.data, xlev = model$xlevels, splineParams=splineParams)
  modmat <- model.matrix(Terms, m)
  
  offset <- rep(0, nrow(modmat))
  # offset specified as term
  if (!is.null(off.num <- attr(tt, "offset"))) 
    for (i in off.num) offset <- offset + exp(eval(attr(tt, "variables")[[i + 1]], predict.data))
  # offset specified as parameter in call
  if (!is.null(model$call$offset)) 
    offset <- offset + eval(model$call$offset, predict.data)
  
  
  if (is.null(coeff)) {
    modcoef <- as.vector(model$coefficients)
  }
  else {
    modcoef <- coeff
  }
  if (type == "response") {
    if (length(model$offset) > 0 & sum(model$offset) !=
        0) {
        preds <- model$family$linkinv(modmat %*% modcoef) *
        offset
    }
    else {
      preds <- model$family$linkinv(modmat %*% modcoef)
    }
  }
  if (type == "link") {
    preds <- modmat %*% modcoef
    print("warning: no offset included as link response specified")
  }
  return(preds)
}

