#==========================================================================================#
#==========================================================================================#
#   This function fits multiple univariate distributions to a vector, and selects the
# one with the lowest BIC, unless a specific distribution has been provided. This function
# relies heavily on function 'fitdistr' (package MASS).
#
# Input:
#
# x      -- A numeric vector containing at least 'xmin' finite values.
# nx_min -- Minimum number of valid points to consider fitting any distribution.
#------------------------------------------------------------------------------------------#
FindBestDistr <<- function(x, nx_min = 10L, verbose = FALSE){
   #---~---
   #   Remove non-finite points 
   #---~---
   xfit     = x[is.finite(x)]
   nxfit    = length(xfit)
   negative = all(xfit %lt% 0)
   positive = all(xfit %gt% 0)
   #---~---


   #---~---
   #   Initialise the answer with no information.
   #---~---
   ans = data.frame( N               = nxfit
                   , xLwr            = NA_real_
                   , xUpr            = NA_real_
                   , Distr           = NA_character_
                   , First           = NA_real_
                   , SE_First        = NA_real_
                   , Second          = NA_real_
                   , SE_Second       = NA_real_
                   , Third           = NA_real_
                   , SE_Third        = NA_real_
                   , LogLik          = NA_real_
                   , BIC             = +Inf
                   , stringAsFactors = FALSE
                   )#end data.frame
   #---~---



   #---~---
   #   Skip fitting if the vector does not have valid data.
   #---~---
   if (nxfit < nx_min) return(ans)
   #---~---



   #---~---
   #   Uniform distribution. This is the first distribution tested, so we always copy 
   # the parameters. Unlike the other distributions, the uniform cannot be solved through
   # fitdistr. Instead, we simply estimate the parameters to be the minimum and maximum
   # values of the vector. All other distributions will be tested against this 
   # distribution.
   #---~---
   ans$xLwr      = min(xfit)
   ans$xUpr      = max(xfit)
   this_loglik   = - nxfit * log(ans$xUpr - ans$xLwr)
   ans$Distr     = "uniform"
   ans$First     = ans$xLwr
   ans$SE_First  = NA_real_
   ans$Second    = ans$xUpr
   ans$SE_Second = NA_real_
   ans$Third     = NA_real_
   ans$SE_Third  = NA_real_
   ans$LogLik    = this_loglik
   ans$BIC       = 2*log(nxfit) - 2. * this_loglik
   if (verbose){
      cat0("     * Uniform: (min=",ans$First,"; max=",ans$Second,"); BIC = ",ans$BIC)
   }#end if (verbose)
   #---~---




   #---~---
   #   Normal distribution. This is the first distribution tested, so we always copy 
   # the parameters. If the optimisation converges and yields a better model than
   # the uniform distribution, select it.
   #---~---
   this_fit   = MASS::fitdistr(x=xfit,densfun="normal")
   this_bic   = 2*log(nxfit) - 2. * this_fit$loglik
   if (this_bic %lt% ans$BIC){
      ans$Distr     = "normal"
      ans$First     = this_fit$estimate[["mean"]]
      ans$SE_First  = this_fit$sd      [["mean"]]
      ans$Second    = this_fit$estimate[["sd"  ]]
      ans$SE_Second = this_fit$sd      [["sd"  ]]
      ans$Third     = NA_real_
      ans$SE_Third  = NA_real_
      ans$LogLik    = this_fit$loglik
      ans$BIC       = this_bic
   }#end if (this_bic %lt% ans$bic)
   if (verbose){
      First  = this_fit$estimate[["mean"]]
      Second = this_fit$estimate[["sd"  ]]
      cat0("     * Normal: (mean=",First,"; SD=",Second,"); BIC = ",this_bic)
   }#end if (verbose)
   #---~---



   #---~---
   #   Logistic distribution. If the optimisation converges and yields a better model than
   # the best current distribution, select it.
   #---~---
   this_fit = try( MASS::fitdistr(x=xfit,densfun="logistic"), silent = TRUE)
   if ( ! "try-error" %in% is(this_fit)){
      this_bic = 2*log(nxfit) - 2. * this_fit$loglik
      if (this_bic %lt% ans$BIC){
         ans$Distr     = "logistic"
         ans$First     = this_fit$estimate[["location"]]
         ans$SE_First  = this_fit$sd      [["location"]]
         ans$Second    = this_fit$estimate[["scale"   ]]
         ans$SE_Second = this_fit$sd      [["scale"   ]]
         ans$Third     = NA_real_
         ans$SE_Third  = NA_real_
         ans$LogLik    = this_fit$loglik
         ans$BIC       = this_bic
      }#end if (this_bic %lt% ans$bic)
      #---~---

      if (verbose){
         First  = this_fit$estimate[["location"]]
         Second = this_fit$estimate[["scale"   ]]
         cat0("     * Logistic: (mean=",First,"; SD=",Second,"); BIC = ",this_bic)
      }#end if (verbose)
   }else if (verbose){
      cat0("     * Logistic distribution did not converge.")
   }#end if ( ! "try-error" %in% is(fit_this))
   #---~---



   #---~---
   #   Skew-normal distribution. First, use function sn_guess (see below) to define
   # first guesses based on the estimator from package "sn". Then fit the distribution
   # using fitdistr. If the optimisation converges and yields a better model than the
   # current best distribution, select it.
   #---~---
   sn_1st   = sn_guess(xfit)
   this_fit = try( expr   = MASS::fitdistr(x=xfit,densfun=sn::dsn,start=sn_1st)
                 , silent = TRUE
                 )#end try
   if ( ! "try-error" %in% is(this_fit)){
      #---~---
      #   Check whether this is a better fit.
      #---~---
      this_bic = 3*log(nxfit) - 2. * this_fit$loglik
      if (this_bic %lt% ans$BIC){
         ans$Distr     = "skew-normal"
         ans$First     = this_fit$estimate[["xi"   ]]
         ans$SE_First  = this_fit$sd      [["xi"   ]]
         ans$Second    = this_fit$estimate[["omega"]]
         ans$SE_Second = this_fit$sd      [["omega"]]
         ans$Third     = this_fit$estimate[["alpha"]]
         ans$SE_Third  = this_fit$sd      [["alpha"]]
         ans$LogLik    = this_fit$loglik
         ans$BIC       = this_bic
      }#end if (this_bic %lt% ans$bic)
      #---~---


      if (verbose){
         First  = this_fit$estimate[["xi"   ]]
         Second = this_fit$estimate[["omega"]]
         Third  = this_fit$estimate[["alpha"]]
         cat0("     * Skew-Normal: (location=",First,"; scale=",Second,"; shape=",Third,");"
                                 ," BIC = ",this_bic)
      }#end if (verbose)
   }else if (verbose){
      cat0("     * Skew-normal distribution did not converge.")
   }#end if ( ! "try-error" %in% is(fit_this))
   #---~---



   #---~---
   #   Log-normal distribution. We can only attempt this if the data are all positive.
   # In case so, and if the optimisation yields a better model than the current best 
   # distribution, select it.
   #---~---
   if (positive){
      this_fit = MASS::fitdistr(x=xfit,densfun="log-normal")
      this_bic = 2*log(nxfit) - 2. * this_fit$loglik

      #---~---
      #   Check for convergence.
      #---~---
      if (this_bic %lt% ans$BIC){
         ans$Distr     = "log-normal"
         ans$First     = this_fit$estimate[["meanlog"]]
         ans$SE_First  = this_fit$sd      [["meanlog"]]
         ans$Second    = this_fit$estimate[["sdlog"  ]]
         ans$SE_Second = this_fit$sd      [["sdlog"  ]]
         ans$Third     = NA_real_
         ans$SE_Third  = NA_real_
         ans$LogLik    = this_fit$loglik
         ans$BIC       = this_bic
      }#end if (this_bic %lt% ans$bic)
      #---~---

      if (verbose){
         First  = this_fit$estimate[["meanlog"]]
         Second = this_fit$estimate[["sdlog"  ]]
         cat0("     * Log-Normal: (meanlog=",First,"; sdLog=",Second,"); BIC = ",this_bic)
      }#end if (verbose)
   }else if (negative){
      xtrans   = -log(-xfit)
      nl_1st   = list(meannlog=mean(xtrans),sdnlog=sd(xtrans))
      this_fit = MASS::fitdistr(x=xfit,densfun=dnlnorm,start=nl_1st)
      this_bic = 2*log(nxfit) - 2. * this_fit$loglik

      #---~---
      #   Check for convergence.
      #---~---
      if (this_bic %lt% ans$BIC){
         ans$Distr     = "neglog-normal"
         ans$First     = this_fit$estimate[["meannlog"]]
         ans$SE_First  = this_fit$sd      [["meannlog"]]
         ans$Second    = this_fit$estimate[["sdnlog"  ]]
         ans$SE_Second = this_fit$sd      [["sdnlog"  ]]
         ans$Third     = NA_real_
         ans$SE_Third  = NA_real_
         ans$LogLik    = this_fit$loglik
         ans$BIC       = this_bic
      }#end if (this_bic %lt% ans$bic)
      #---~---

      if (verbose){
         First  = this_fit$estimate[["meannlog"]]
         Second = this_fit$estimate[["sdnlog"  ]]
         cat0("     * Neg-Log-Normal: (meannlog=",First,"; sdLog=",Second,");"
                                    ," BIC = ",this_bic)
      }#end if (verbose)
   }else if (verbose){
      cat0("     * Skip fitting log-normal. Positive and negative data present")
   }#end if (positive)
   #---~---



   #---~---
   #   Weibull distribution. We can only attempt this if the data are all positive.
   # In case so, and if the optimisation yields a better model than the current best 
   # distribution, select it.
   #---~---
   if (positive){
      this_fit = try( MASS::fitdistr(x=xfit,densfun="weibull"), silent = TRUE)

      #---~---
      #   Check for convergence.
      #---~---
      if (! "try-error" %in% is(this_fit)){
         this_bic = 2*log(nxfit) - 2. * this_fit$loglik
         if (this_bic %lt% ans$BIC){
            ans$Distr     = "weibull"
            ans$First     = this_fit$estimate[["shape"]]
            ans$SE_First  = this_fit$sd      [["shape"]]
            ans$Second    = this_fit$estimate[["scale"]]
            ans$SE_Second = this_fit$sd      [["scale"]]
            ans$Third     = NA_real_
            ans$SE_Third  = NA_real_
            ans$LogLik    = this_fit$loglik
            ans$BIC       = this_bic
         }#end if (this_bic %lt% ans$bic)
         #---~---

         if (verbose){
            First  = this_fit$estimate[["shape"]]
            Second = this_fit$estimate[["scale"]]
            cat0("     * Weibull: (shape=",First,"; scale=",Second,"); BIC = ",this_bic)
         }#end if (verbose)
      }else if (verbose){
         cat0("     * Weibull distribution did not converge.")
      }#end if (! "try-error" %in% is(this_fit))
      #---~---
   }else if (verbose){
      cat0("     * Skip fitting Weibull. Negative data present")
   }#end if (positive)
   #---~---



   #---~---
   #   Gamma distribution. We can only attempt this if the data are all positive.
   # In case so, and if the optimisation yields a better model than the current best 
   # distribution, select it.
   #---~---
   if (positive){
      this_fit = try( MASS::fitdistr(x=xfit,densfun="gamma"), silent = TRUE)

      #---~---
      #   Check for convergence.
      #---~---
      if (! "try-error" %in% is(this_fit)){
         this_bic = 2*log(nxfit) - 2. * this_fit$loglik
         if (this_bic %lt% ans$BIC){
            ans$Distr     = "gamma"
            ans$First     = this_fit$estimate[["shape"]]
            ans$SE_First  = this_fit$sd      [["shape"]]
            ans$Second    = this_fit$estimate[["rate" ]]
            ans$SE_Second = this_fit$sd      [["rate" ]]
            ans$Third     = NA_real_
            ans$SE_Third  = NA_real_
            ans$LogLik    = this_fit$loglik
            ans$BIC       = this_bic
         }#end if (this_bic %lt% ans$bic)
         #---~---

         #---~---
         #   Report estimate for verbose calls
         #---~---
         if (verbose){
            First  = this_fit$estimate[["shape"]]
            Second = this_fit$estimate[["rate" ]]
            cat0("     * Gamma: (shape=",First,"; rate=",Second,"); BIC = ",this_bic)
         }#end if (verbose)
         #---~---
      }else if (verbose){
         cat0("     * Gamma distribution did not converge.")
      }#end if (this_bic %lt% ans$bic)
      #---~---
   }else if (verbose){
      cat0("     * Skip fitting Gamma. Negative data present")
   }#end if (positive)
   #---~---



   #---~---
   #   Provide the answer
   #---~---
   return(ans)
   #---~---
}#end function FindBestDistr
#==========================================================================================#
#==========================================================================================#
