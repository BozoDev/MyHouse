rrdtool create piko.rrd --step 30 \
DS:l1i:GAUGE:50:0:65535 \
DS:l2i:GAUGE:50:0:65535 \
DS:l3i:GAUGE:50:0:65535 \
DS:l1p:GAUGE:50:0:65535 \
DS:l2p:GAUGE:50:0:65535 \
DS:l3p:GAUGE:50:0:65535 \
RRA:MAX:0.5:2:20160 \
RRA:MIN:0.5:2:20160 \
RRA:AVERAGE:0.5:2:20160
