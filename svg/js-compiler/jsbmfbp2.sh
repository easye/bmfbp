#!/bin/bash
NAME=$(basename $1 .svg)

if grep -q "Not supported by viewer" $1 ; then
   echo "BAD svg (contains Not supported by viewer)"
   exit 1
fi

# scanner
hs_vsh_drawio_to_fb <$1 >temp1.lisp
lib_insert_part_name $NAME <temp1.lisp >temp2.lisp
fb_to_prolog $NAME <temp2.lisp >temp3.pro
sort <temp3.pro >temp4.pro
check_input $NAME <temp4.pro >temp5.pro

# parser
calc_bounds $NAME <temp5.pro >temp6.pro
find_comments $NAME <temp6.pro >temp7.pro
find_metadata $NAME <temp7.pro >temp8.pro
add_kinds $NAME <temp8.pro >temp9.pro
add_selfPorts $NAME <temp9.pro >temp10.pro
make_unknown_port_names $NAME <temp10.pro >temp11.pro
create_centers $NAME <temp11.pro >temp12.pro
calculate_distances $NAME <temp12.pro >temp13.pro
assign_portnames $NAME <temp13.pro >temp14.pro
markIndexedPorts $NAME <temp14.pro >temp15.pro
coincidentPorts $NAME <temp15.pro >temp16.pro
mark_directions $NAME <temp16.pro >temp17.pro
match_ports_to_components <temp17.pro >temp18.pro

# semantics
sem_partsHaveSomePorts <temp18.pro >temp19.pro
sem_allPortsHaveAnIndex <temp19.pro >temp20a.pro
sem_noDuplicateKinds <temp20a.pro >temp20b.pro
sem_speechVScomments <temp20b.pro >temp20.pro

# emitter
assign_wire_numbers_to_inputs $NAME <temp20.pro >temp21.pro
assign_wire_numbers_to_outputs $NAME <temp21.pro >temp22.pro
assign_portIndices $NAME <temp22.pro >temp23.pro
inOutPins <temp23.pro >temp24.pro

loginfo <temp24.pro >temp25.pro
dumplog <temp25.pro 2>temp.log-unfixed.txt

if grep -q 'ATAL' temp.log-unfixed.txt ; then
    cat temp.log-unfixed.txt
    echo QUIT
    exit 1
else    
    emit_js $NAME <temp25.pro >temp26.lisp
    unmap-strings $NAME <temp26.lisp >temp27.lisp
    emit_js2 $NAME <temp27.lisp >temp28.json
    sed -f strings.sed <temp.log-unfixed.txt >temp.log.txt
fi
