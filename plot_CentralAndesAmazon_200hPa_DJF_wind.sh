#!/bin/bash
gmt gmtset MAP_FRAME_PEN    2
gmt gmtset MAP_FRAME_WIDTH    0.1
gmt gmtset MAP_FRAME_TYPE     plain
gmt gmtset FONT_TITLE    Helvetica-Bold 18p
gmt gmtset FONT_LABEL    Helvetica-Bold 14p
gmt gmtset PS_PAGE_ORIENTATION    portrait
gmt gmtset PS_MEDIA    A4
gmt gmtset FORMAT_GEO_MAP    D
gmt gmtset MAP_DEGREE_SYMBOL degree
gmt gmtset PROJ_LENGTH_UNIT cm

REGION=-85/-30/-40/15

#generate global hillshade (only needs to be done once)
TOPO15_GRD_NC=/home/bodo/Dropbox/data/TOPO15/earth_relief_15s.nc
TOPO15_GRD_NC_CentralAndesAmazon=earth_relief_15s_CentralAndesAmazon.nc
if [ ! -e $TOPO15_GRD_NC_CentralAndesAmazon ]
then
    echo "generate Topo15S Clip $TOPO15_GRD_NC_CentralAndesAmazon"
    gmt grdcut -R$REGION $TOPO15_GRD_NC -G$TOPO15_GRD_NC_CentralAndesAmazon
fi

TOPO15_GRD_NC=$TOPO15_GRD_NC_CentralAndesAmazon
TOPO15_GRD_HS_NC=earth_relief_15s_CentralAndesAmazon_HS.nc
if [ ! -e $TOPO15_GRD_HS_NC ]
then
    echo "generate hillshade $TOPO15_GRD_HS_NC"
    gmt grdgradient $TOPO15_GRD_NC -Ne0.6 -Es75/55+a -G$TOPO15_GRD_HS_NC
fi

#Simpler Peucker algorithm
TOPO15_GRD_HS2_NC=earth_relief_15s_CentralAndesAmazon_HS_peucker.nc
if [ ! -e $TOPO15_GRD_HS2_NC ]
then
    echo "generate hillshade $TOPO15_GRD_HS2_NC"
    gmt grdgradient $TOPO15_GRD_NC -Nt1 -Ep -G$TOPO15_GRD_HS2_NC
fi


#Set DATA grids
ECMWF_WND="ECMWF-EI-WND_1999_2013_DJF_200_SAM.nc"

#Convert windspeed and wind direction from u and v component of the wind
#First, convert file containing both wind direction into separate files (easier to work with)
gmt grdconvert ${ECMWF_WND}?u -G${ECMWF_WND::-3}_u.nc
#Change from longitude 0-360 to -180 to +180 (just more convenient)
gmt grdedit ${ECMWF_WND::-3}_u.nc -R-85/-30/-40/15
#For plotting with GMT, we have to reverse the notation:
gmt grdmath ${ECMWF_WND::-3}_u.nc NEG = ${ECMWF_WND::-3}_u.nc

#same for v component:
gmt grdconvert ${ECMWF_WND}?v -G${ECMWF_WND::-3}_v.nc
gmt grdedit ${ECMWF_WND::-3}_v.nc -R-85/-30/-40/15
gmt grdmath ${ECMWF_WND::-3}_v.nc NEG = ${ECMWF_WND::-3}_v.nc

#calculate wind magnitude / velocity
gmt grdmath ${ECMWF_WND::-3}_v.nc 2 POW ${ECMWF_WND::-3}_u.nc 2 POW ADD SQRT = ${ECMWF_WND::-3}_magnitude.nc
gmt grdedit ${ECMWF_WND::-3}_magnitude.nc -D+z"Wind Magnitude"+r"sqrt(u^2 plus v^2)"

#resample wind magnitude to topographic TOPO15 GRID
if [ ! -e ${ECMWF_WND::-3}_magnitude_topo15.nc ]
then
    echo "resample to ${ECMWF_WND::-3}_magnitude_topo15.nc"
    gmt grdsample ${ECMWF_WND::-3}_magnitude.nc -R$TOPO15_GRD_NC -G${ECMWF_WND::-3}_magnitude_topo15.nc
fi

#Set Parameters for Plot
POSTSCRIPT_BASENAME=ECMWF-EI-WND_1999_2013_DJF_200_SAM
#xmin/xmax/ymin/ymax
WIDTH=10
XSTEP=10
YSTEP=10

TITLE="ECMWF-WND DJF mean (1999-2013) - 200hPa"
POSTSCRIPT1=${POSTSCRIPT_BASENAME}_graytopo.ps
#Make colorscale
DEM_CPT=relief_gray.cpt
gmt makecpt -T-4000/4000/250 -D -Cgray >$DEM_CPT
WIND_CPT=wind_color.cpt
gmt makecpt -T0/25/0.5 -D -Cviridis >$WIND_CPT
VECTSCALE=0.04c
echo " "
echo "Creating file $POSTSCRIPT1"
echo " "
gmt grdimage $TOPO15_GRD_NC -I$TOPO15_GRD_HS2_NC -JM$WIDTH -C$DEM_CPT -R${ECMWF_WND::-3}_u.nc -Q -Bx$XSTEP -By$YSTEP -BWSne+t"$TITLE" -Xc -Yc -E300 -K -P > $POSTSCRIPT1
gmt pscoast -W1/thin,black -R -J -N1/faint,gray -O -Df --FONT_ANNOT_PRIMARY=12p --FORMAT_GEO_MAP=ddd:mm:ssF -P -K >> $POSTSCRIPT1
gmt grdvector -Gblack -S${VECTSCALE} -Q0.25c+ba -W0.5 ${ECMWF_WND::-3}_u.nc ${ECMWF_WND::-3}_v.nc -C$WIND_CPT -R -Ix8 -J -O -K -P >> $POSTSCRIPT1
gmt psscale -R -J -DjBC+h+o-1.7c/-2.0c/+w5c/0.3c -C$WIND_CPT -F+gwhite+r1p+pthin,black -Baf -By+l"Wind Velocity (m/s)" --FONT=9p --FONT_ANNOT_PRIMARY=9p --MAP_FRAME_PEN=1 --MAP_FRAME_WIDTH=0.1 -O -P >> $POSTSCRIPT1
gmt psconvert $POSTSCRIPT1 -A -P -Tg
convert -alpha off -quality 100 -density 150 $POSTSCRIPT1 ${POSTSCRIPT1::-3}.jpg

POSTSCRIPT1=${POSTSCRIPT_BASENAME}_relieftopo.ps
#Make colorscale
DEM_CPT=relief_color.cpt
gmt makecpt -T-4000/4000/250 -D -Crelief >$DEM_CPT
VECTSCALE=0.04c
echo " "
echo "Creating file $POSTSCRIPT1"
echo " "
gmt grdimage $TOPO15_GRD_NC -I$TOPO15_GRD_HS_NC -JM$WIDTH -C$DEM_CPT -R${ECMWF_WND::-3}_u.nc -Q -Bx$XSTEP -By$YSTEP -BWSne+t"$TITLE" -Xc -Yc -E300 -K -P > $POSTSCRIPT1
gmt pscoast -W1/thin,black -R -J -N1/faint,gray -O -Df --FONT_ANNOT_PRIMARY=12p --FORMAT_GEO_MAP=ddd:mm:ssF -P -K >> $POSTSCRIPT1
gmt grdvector -Gblack -S${VECTSCALE} -Q0.3c+ba ${ECMWF_WND::-3}_u.nc ${ECMWF_WND::-3}_v.nc -C$WIND_CPT -R -Ix8 -J -O -K -P >> $POSTSCRIPT1
gmt psscale -R -J -DjBC+h+o-1.7c/-2.0c/+w5c/0.3c -C$WIND_CPT -F+gwhite+r1p+pthin,black -Baf -By+l"Wind Velocity (m/s)" --FONT=9p --FONT_ANNOT_PRIMARY=9p --MAP_FRAME_PEN=1 --MAP_FRAME_WIDTH=0.1 -O -P >> $POSTSCRIPT1
gmt psconvert $POSTSCRIPT1 -A -P -Tg
convert -alpha off -quality 100 -density 150 $POSTSCRIPT1 ${POSTSCRIPT1::-3}.jpg


POSTSCRIPT1=${POSTSCRIPT_BASENAME}_windvelocity.ps
#Make colorscale
VECTSCALE=0.04c
echo " "
echo "Creating file $POSTSCRIPT1"
echo " "
gmt grdimage ${ECMWF_WND::-3}_magnitude_topo15.nc -I$TOPO15_GRD_HS_NC -JM$WIDTH -C$WIND_CPT -R${ECMWF_WND::-3}_u.nc -Q -Bx$XSTEP -By$YSTEP -BWSne+t"$TITLE" -Xc -Yc -E300 -K -P > $POSTSCRIPT1
gmt pscoast -W1/thin,black -R -J -N1/faint,gray -O -Df --FONT_ANNOT_PRIMARY=12p --FORMAT_GEO_MAP=ddd:mm:ssF -P -K >> $POSTSCRIPT1
gmt grdvector -Gblack -S${VECTSCALE} -Q0.25c+ba ${ECMWF_WND::-3}_u.nc ${ECMWF_WND::-3}_v.nc -R -Ix7 -J -O -K -P >> $POSTSCRIPT1
gmt psscale -R -J -DjBC+h+o-1.7c/-2.0c/+w5c/0.3c -C$WIND_CPT -F+gwhite+r1p+pthin,black -Baf -By+l"Wind Velocity (m/s)" --FONT=9p --FONT_ANNOT_PRIMARY=9p --MAP_FRAME_PEN=1 --MAP_FRAME_WIDTH=0.1 -O -P >> $POSTSCRIPT1
gmt psconvert $POSTSCRIPT1 -A -P -Tg
convert -alpha off -quality 100 -density 150 $POSTSCRIPT1 ${POSTSCRIPT1::-3}.jpg




#Will need more work to plot unit vector:
# SCUNITVECT=$( echo  "scale=8; $REFVECT/$VECTSCALE" | bc ) 
# #   x-position  y-position  direction  length
# #psxy -R -J -D3.0i/${VSCALEOFF}i/5.0i/0.2i  -Sv0.008i/0.06i/0.03i -L -G0 -N -W1 -O -K   << EOF >> $OFILE
# VSCALEOFF=-0.2
# $GMTPRE psxy -R -J -D-0.3i/${VSCALEOFF}i  -Sv0.008i/0.06i/0.03i -L -G0 -N -W1 -O -K   << EOF >> $OFILE
#   0  0  0   $SCUNITVECT
# EOF
# VSCALEOFF=-0.3
# # PSTEXT Make text to overlay GMT plot
# # (x, y, size, angle, fontno, justify, text) see help gmt_plot
# #pstext -R -J  -D5.0i/${VSCALEOFF}i/5.0i/0.2i   -N -O  << EOF >> $OFILE
# $GMTPRE pstext -R -J  -D-0.3i/${VSCALEOFF}i   -N -O -K << EOF >> $OFILE
#   0  0  12 0 1 LT $REFVECT $VECTUNITS
# EOF
# #


# # COMBINE plots with imagemagick
# convert -quality 50 -density 150 ${POSTSCRIPT_BASENAME}_DEM_lvl8points.png ${POSTSCRIPT_BASENAME}_NDVI.png ${POSTSCRIPT_BASENAME}_E_steep.png ${POSTSCRIPT_BASENAME}_N_steep.png -fuzz 1% -trim -bordercolor white -border 10x0 +repage +append ${POSTSCRIPT_BASENAME}_DEM_NDVI_E_N_steepening_combined.jpg
# 
# convert -quality 100 -density 300 ${POSTSCRIPT_BASENAME}_DEM_lvl8points.png ${POSTSCRIPT_BASENAME}_NDVI.png ${POSTSCRIPT_BASENAME}_E_steep.png ${POSTSCRIPT_BASENAME}_N_steep.png -fuzz 1% -trim -bordercolor white -border 10x0 +repage +append ${POSTSCRIPT_BASENAME}_DEM_NDVI_E_N_steepening_combined.png
