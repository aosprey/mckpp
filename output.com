      INTEGER N_VAROUTS,N_SINGOUTS,N_ZPROFS_MAX
      PARAMETER (N_VAROUTS=25,N_SINGOUTS=15,N_ZPROFS_MAX=5)
      INTEGER ndt_varout_inst(N_VAROUTS),ndt_singout_inst(N_SINGOUTS),
     +     ndt_varout_mean(N_VAROUTS),ndt_singout_mean(N_SINGOUTS),
     +     ndt_varout_range(N_VAROUTS),ndt_singout_range(N_SINGOUTS),
     +     zprof_varout_inst(N_VAROUTS),
     +     zprof_varout_mean(N_VAROUTS),
     +     zprof_varout_range(N_VAROUTS)
      LOGICAL L_OUTPUT_MEAN, L_OUTPUT_INST, L_OUTPUT_RANGE
      LOGICAL L_RESTARTW, zprofs_mask(NZP1,0:N_ZPROFS_MAX)
      CHARACTER*5 restart_time
      INTEGER nout,nout_mean,ndt_per_restart
      INTEGER zprofs(NZP1,N_ZPROFS_MAX),zprofs_nvalid(0:N_ZPROFS_MAX)
      REAL*4 dtout
      REAL*4 missval
      PARAMETER (missval=1.e20)
************************************************************************
* Common blocks to control outputs, each variable has a number associated 
* with it given below
*
*     VAROUTS
*     1    =    U field     (m/s)
*     2    =    V field     (m/s)
*     3    =    T field     (degC)
*     4    =    S field     (o/oo)
*     5    =    Buoyancy    (m/s2)
*
*     6    =    w'u'        (m2/s2)
*     7    =    w'v'        (m2/s2)
*     8    =    w'T'        (degC m/s)
*     9    =    w'S'        (o/oo m/s)
*     10   =    w'B'        (m2/s3)
*
*     11   =    w'T'(NT)    (degC m/s)
*
*     12   =    difm        (m2/s)
*     13   =    dift        (m2/s)
*     14   =    difs        (m2/s)
*
*     15   =    rho         (kg/m3)
*     16   =    cp          (J/kg/K)
*    
*     17   =    scorr       (o/oo/s)
*     18   =    Rig         (local Richardson number in kpp.f - NPK diagnostic)
*     19   =    dbloc       (local delta buoyancy used to calculate Rig - NPK diagnostic)
*     20   =    shsq        (local shear-squared term used to calculate Rig - NPK diagnostic)
*     21   =    tinc_fcorr  (temperature increment from flux corrections with depth, K)
*     22   =    ocnTcorr    (K/s)
*     23   =    sinc_fcorr  (salinity increment from flux corrections with depth,o/oo)
*     24   =    tinc_ekadv  (temperature increment from Ekman pumping vertical advection, K)
*     25   =    sinc_ekadv  (salinity increment from Ekman pumping vertical advection, o/oo)
*
*     SINGOUTS
*     1 = hmix     (m)  : single level field.
*     2 = fcorr    (W/m^2) : single level field
*     3 = taux_in  (N/m^2)
*     4 = tauy_in  (N/m^2)
*     5 = solar_in    (W/m^2)*     6 = nsolar_in   (W/m^2)
*     7 = PminusE_in  (W/m^2)
*     8 = cplwght
*     9 = freeze_flag (unitless) : fraction of levels at which temperature was < -1.8C and was reset to -1.8C.
*    10 = isotherm_flag (unitless)  : 1/0 for whether T/S profile was reset to climatology because of isothermal detection routine
*    11 = dampu_flag (unitless) : flag for Ui in damping of currents (ocn.f), U**2/r < alpha*U =1, U**2/r > alpha*U =-1. output is total of all levels. If dampu_flag =NZ all levels U**2/r<alpha*U (alpha = 0.99, r=tau*(86400/dto), tau=360). 
*    12 = dampv_flag (unitless) : as for dampu_flag but for v.
*    13 = fcorr_nsol (W/m^2) : non-solar heat-flux restoring term, computed as fcorr_nsol_coeff * (SST_model - SST_clim)
*    14 = hekman (m) : diagnosed depth of Ekman layer
*    15 = runoff_incr (kg/m^2/s): increment to surface freshwater flux from re-distributing global river runoff
************************************************************************
      INTEGER ncid_out,mean_ncid_out,min_ncid_out,max_ncid_out,
     +     day_out,flen,ndt_per_file
      CHARACTER*200 output_dir
      CHARACTER*250 output_file,mean_output_file,
     +     min_output_file,max_output_file
      CHARACTER*217 restart_outfile
      INTEGER londim,latdim,zdim,ddim,hdim,timdim
      INTEGER lon_id,lat_id,z_id,h_id,d_id,time_id

      INTEGER varid_vec(N_VAROUTS),varid_sing(N_SINGOUTS),
     &     varid_vec_mean(N_VAROUTS),varid_sing_mean(N_SINGOUTS),
     &     varid_vec_range(N_VAROUTS),varid_sing_range(N_SINGOUTS),
     &     ntout_vec_inst(N_VAROUTS),ntout_sing_inst(N_SINGOUTS),
     &     ntout_vec_mean(N_VAROUTS),ntout_sing_mean(N_SINGOUTS),
     &     ntout_vec_range(N_VAROUTS),ntout_sing_range(N_SINGOUTS)
      INTEGER NVEC_MEAN,NSCLR_MEAN,NVEC_RANGE,NSCLR_RANGE
      PARAMETER(NVEC_MEAN=N_VAROUTS,NSCLR_MEAN=N_SINGOUTS,
     +     NVEC_RANGE=N_VAROUTS,NSCLR_RANGE=N_SINGOUTS)
            
      common /output/ ndt_varout_inst,ndt_singout_inst,ndt_varout_mean,
     &     ndt_singout_mean,ndt_varout_range,ndt_singout_range,
     &     zprof_varout_inst,zprof_varout_mean,
     &     zprof_varout_range,
     &     dtout,nout,nout_mean,restart_outfile,
     &     l_restartw,l_output_mean,l_output_inst,l_output_range,
     &	   ndt_per_restart,restart_time,zprofs,zprofs_mask,zprofs_nvalid
      common /ncdf_out/ mean_ncid_out,ncid_out,londim,latdim,zdim,ddim,
     &     hdim,timdim,time_id,varid_vec,varid_sing,day_out,
     &     output_file,flen,mean_output_file,varid_vec_mean,
     &     varid_sing_mean,ndt_per_file,ntout_vec_inst,ntout_sing_inst,
     &     ntout_vec_mean,ntout_sing_mean,min_output_file,max_ncid_out,
     &     max_output_file,ntout_vec_range,ntout_sing_range,
     &     min_ncid_out,varid_vec_range,varid_sing_range,output_dir

