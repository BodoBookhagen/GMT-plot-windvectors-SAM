#!/bin/bash
gmt gmtset MAP_FRAME_PEN    0.5p,black
gmt gmtset MAP_FRAME_WIDTH    0.1
gmt gmtset MAP_FRAME_TYPE     plain
gmt gmtset FONT_TITLE    14p,Helvetica-Bold,black
gmt gmtset FONT_LABEL    12p,Helvetica,black
gmt gmtset FONT_ANNOT_PRIMARY   12p,Helvetica,black
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
AltiplanoPuna_1bas=AltiplanoPuna_1basin_UTM19S_WGS84.gmt

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
POSTSCRIPT_BASENAME=ECMWF-EI-WND_1999_2013_DJF_200hpa_SAM
#xmin/xmax/ymin/ymax
WIDTH=14
XSTEP=10
YSTEP=10

TITLE="ECMWF-WND DJF mean (1999-2013) - 200hPa"
POSTSCRIPT1=${POSTSCRIPT_BASENAME}_graytopo.ps
#Make colorscale
DEM_CPT=relief_gray.cpt
gmt makecpt -T-5000/5000/250 -D -Cgray >$DEM_CPT
WIND_CPT=wind_color.cpt
gmt makecpt -T0/30/1 -D -Cviridis >$WIND_CPT
VECTSCALE=0.04c
VECTSCALE2=0.02c
echo " "
echo "Creating file $POSTSCRIPT1"
echo " "
#gmt grdimage $TOPO15_GRD_NC -I$TOPO15_GRD_HS2_NC -JM$WIDTH -C$DEM_CPT -R${ECMWF_WND::-3}_u.nc -Q -Bx$XSTEP -By$YSTEP -BWSne -Xc -Yc -E300 -K -P > $POSTSCRIPT1
gmt grdimage $TOPO15_GRD_NC -I$TOPO15_GRD_HS2_NC -JM$WIDTH -C$DEM_CPT -R${ECMWF_WND::-3}_u.nc -Q -Bx$XSTEP -By$YSTEP -BWSne -Xc -Yc -E300 -K -P > $POSTSCRIPT1
gmt pscoast -W1/thin,black -R -J -N1/thin,gray -O -Df --FORMAT_GEO_MAP=ddd:mm:ssF -P -K >> $POSTSCRIPT1
gmt psxy $AltiplanoPuna_1bas -R -J -L -Wthick,white -K -O -P >> $POSTSCRIPT1
gmt grdvector -S${VECTSCALE} -W1.5p ${ECMWF_WND::-3}_u.nc ${ECMWF_WND::-3}_v.nc -C$WIND_CPT -R -Ix6 -J -O -K -P >> $POSTSCRIPT1
gmt grdvector -S${VECTSCALE2} -Q0.6c+ba+p0.01p,gray -W0.01p,gray ${ECMWF_WND::-3}_u.nc ${ECMWF_WND::-3}_v.nc -C$WIND_CPT -R -Ix12 -J -O -K -P >> $POSTSCRIPT1
gmt psxy -W2.5p,red -L << EOF -R -J -O -K -P >> $POSTSCRIPT1
-69 -28
-69 -22
-63 -22
-63 -28
EOF
gmt psxy -W2.5p,gray -Sr << EOF -R -J -O -K -P >> $POSTSCRIPT1
-64 -16 2c 2c
EOF
gmt pstext -D0.7c/1.3c -F+f14p,Helvetica-Bold,gray  << EOF -R -J -O -K -P >> $POSTSCRIPT1
-64 -16 BH
EOF
gmt psscale -R -J -DjBC+h+o-0.5c/-3.0c/+w5c/0.3c -C$WIND_CPT -F+c1c/0.2c+gwhite+r1p+pthin,black -Baf1:"200 hPa DJF wind speed (1999-2013)":/:"[m/s]": --FONT=12p --FONT_ANNOT_PRIMARY=12p --MAP_FRAME_PEN=0.5 --MAP_FRAME_WIDTH=0.1 -O -P >> $POSTSCRIPT1
gmt psconvert $POSTSCRIPT1 -A -P -Tg
convert -alpha off -quality 100 -density 150 $POSTSCRIPT1 ${POSTSCRIPT1::-3}.jpg

POSTSCRIPT1=${POSTSCRIPT_BASENAME}_relieftopo.ps
#Make colorscale
DEM_CPT=relief_color.cpt
gmt makecpt -T-6000/6000/250 -D -Crelief >$DEM_CPT
echo " "
echo "Creating file $POSTSCRIPT1"
echo " "
#gmt grdimage $TOPO15_GRD_NC -I$TOPO15_GRD_HS_NC -JM$WIDTH -C$DEM_CPT -R${ECMWF_WND::-3}_u.nc -Q -Bx$XSTEP -By$YSTEP -BWSne -Xc -Yc -E300 -K -P > $POSTSCRIPT1
gmt grdimage $TOPO15_GRD_NC -I$TOPO15_GRD_HS_NC -JM$WIDTH -C$DEM_CPT -R${ECMWF_WND::-3}_u.nc -Q -Bx$XSTEP -By$YSTEP -BWSne -Xc -Yc -E300 -K -P > $POSTSCRIPT1
gmt pscoast -W1/thin,black -R -J -N1/thin,gray -O -Df --FONT_ANNOT_PRIMARY=12p --FORMAT_GEO_MAP=ddd:mm:ssF -P -K >> $POSTSCRIPT1
gmt psxy $AltiplanoPuna_1bas -R -J -L -Wthick,white -K -O -P >> $POSTSCRIPT1
gmt grdvector -S${VECTSCALE} -W1.5p ${ECMWF_WND::-3}_u.nc ${ECMWF_WND::-3}_v.nc -C$WIND_CPT -R -Ix6 -J -O -K -P >> $POSTSCRIPT1
gmt grdvector -S${VECTSCALE2} -Q0.6c+ba+p0.01p -W0p ${ECMWF_WND::-3}_u.nc ${ECMWF_WND::-3}_v.nc -C$WIND_CPT -R -Ix12 -J -O -K -P >> $POSTSCRIPT1
gmt psxy -W2.5p,red -L << EOF -R -J -O -K -P >> $POSTSCRIPT1
-69 -28
-69 -22
-63 -22
-63 -28
EOF
gmt psxy -W2.5p,white -Sr << EOF -R -J -O -K -P >> $POSTSCRIPT1
-64 -16 2c 2c
EOF
gmt pstext -D0.7c/1.3c -F+f14p,Helvetica-Bold,white  << EOF -R -J -O -K -P >> $POSTSCRIPT1
-64 -16 BH
EOF
gmt psscale -R -J -DjBC+h+o-0.5c/-3.0c/+w5c/0.3c -C$WIND_CPT -F+c1c/0.2c+gwhite+r1p+pthin,black -Baf1:"200 hPa DJF wind speed (1999-2013)":/:"[m/s]": --FONT=12p --FONT_ANNOT_PRIMARY=12p --MAP_FRAME_PEN=0.5 --MAP_FRAME_WIDTH=0.1 -O -P >> $POSTSCRIPT1
gmt psconvert $POSTSCRIPT1 -A -P -Tg
convert -alpha off -quality 100 -density 150 $POSTSCRIPT1 ${POSTSCRIPT1::-3}.jpg


POSTSCRIPT1=${POSTSCRIPT_BASENAME}_windvelocity.ps
#Make colorscale
echo " "
echo "Creating file $POSTSCRIPT1"
echo " "
VECTSCALE=0.04c
VECTSCALE2=0.02c
#gmt grdimage ${ECMWF_WND::-3}_magnitude_topo15.nc -I$TOPO15_GRD_HS_NC -JM$WIDTH -C$WIND_CPT -R${ECMWF_WND::-3}_u.nc -Q -Bx$XSTEP -By$YSTEP -BWSne -Xc -Yc -E300 -K -P > $POSTSCRIPT1
gmt grdimage ${ECMWF_WND::-3}_magnitude_topo15.nc -I$TOPO15_GRD_HS_NC -JM$WIDTH -C$WIND_CPT -R${ECMWF_WND::-3}_u.nc -Q -Bx$XSTEP -By$YSTEP -BWSne -Xc -Yc -E300 -K -P > $POSTSCRIPT1
gmt pscoast -W1/thin,black -R -J -N1/thin,gray -O -Df --FONT_ANNOT_PRIMARY=12p --FORMAT_GEO_MAP=ddd:mm:ssF -P -K >> $POSTSCRIPT1
#gmt grdvector -W1p -S${VECTSCALE} -Q0.3c+ba ${ECMWF_WND::-3}_u.nc ${ECMWF_WND::-3}_v.nc -R -Ix8 -J -O -K -P >> $POSTSCRIPT1
gmt psxy $AltiplanoPuna_1bas -R -J -L -Wthick,white -K -O -P >> $POSTSCRIPT1
#gmt grdvector -S${VECTSCALE} -W0.5p,black ${ECMWF_WND::-3}_u.nc ${ECMWF_WND::-3}_v.nc -C$WIND_CPT -R -Ix4 -J -O -K -P >> $POSTSCRIPT1
gmt grdvector -Gblack -S${VECTSCALE2} -Q0.4c+ba+gblack+pfaint,black -W0p ${ECMWF_WND::-3}_u.nc ${ECMWF_WND::-3}_v.nc -C$WIND_CPT -R -Ix7 -J -O -K -P >> $POSTSCRIPT1
gmt psxy -W2.5p,red -L << EOF -R -J -O -K -P >> $POSTSCRIPT1
-69 -28
-69 -22
-63 -22
-63 -28
EOF
gmt psxy -W2.5p,white -Sr << EOF -R -J -O -K -P >> $POSTSCRIPT1
-64 -16 2c 2c
EOF
gmt pstext -D0.7c/1.3c -F+f14p,Helvetica-Bold,white  << EOF -R -J -O -K -P >> $POSTSCRIPT1
-64 -16 BH
EOF
gmt psscale -R -J -DjBC+h+o-0.5c/-3.0c/+w5c/0.3c -C$WIND_CPT -F+c1c/0.2c+gwhite+r1p+pthin,black -Baf1:"200 hPa DJF wind speed (1999-2013)":/:"[m/s]": --FONT=12p --FONT_ANNOT_PRIMARY=12p --MAP_FRAME_PEN=0.5 --MAP_FRAME_WIDTH=0.1 -O -P >> $POSTSCRIPT1
gmt psconvert $POSTSCRIPT1 -A -P -Tg
convert -alpha off -quality 100 -density 150 $POSTSCRIPT1 ${POSTSCRIPT1::-3}.jpg
