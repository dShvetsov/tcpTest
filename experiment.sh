#!/usr/bin/env bash

if [ -z $(command -v iperf3) ] ; then
    echo "iperf3 wasn't install. Use apt install iperf3"
    exit 1
fi

if [ $UID -ne 0 ] ; then
    echo "Permission denined"
    exit 1
fi

function draw() {
    file=$1
    port=$2
    output_file=$2
    awk -i inplace '$3 ~ /'$port'$/' "$file"

    gnuplot <<< "
set terminal svg size 1000 500 enhanced fname \"Times\" fsize 8 background rgb \"white\"
set output "$output_file"
set style data lines
stats "$file" using 1:7 nooutput
set xrange [STATS_min_x:STATS_max_x]
set yrange [STATS_min_y:STATS_max_y]
set xlabel \"time (seconds)\"
set ylabel \"Segments (cwnd, ssthresh)\"
plot \
"$TCP_PROBE_OUTPUT" using 1:7 title \"snd cwnd\", \
"$TCP_PROBE_OUTPUT" using 1:($8>=2147483647 ? 0 : $8) title \"snd ssthresh\"
set timestamp bottom
show timestamp
"
}

# client and server must be number of it
function run_expirement() {
    client=$1
    server=$2
    algo=$3
    echo "Run iperf betwean h$client and h$server with aloghrithm $algo"
    iperf_server_port=5001
    tcp_probe_output="./tcp_window_${client}_${server}_${algo}".txt
    iperf_server_output="./iperf_server_${client}_${server}_${algo}".txt

    ip netns exec ns$server iperf3 -s -p $iperf_server_port > "$iperf_server_output" & iperf_server_pid=$!
    echo "Iperf server ran.
        Namespace ns$server,
        port $iperf_server_port,
        pid $iperf_server_pid,
        output file $iperf_server_output"

    modprobe tcp_probe port="$iperf_server_port"
    dd if=/proc/net/tcpprobe > "$tcp_probe_output" & tcp_capturing=$!
    echo "tcp_probe ran. Output file $tcp_probe_output , pid $tcp_captuting"

    echo "Run client"
    ip netns exec ns$client iperf3 -t 60 -c 10.255.255.$server -p $iperf_server_port

    echo "Kill tcp probe"
    kill $tcp_capturing
    wait $tcp_capturing
    modprobe -r tcp_probe

    echo "Kill iperf server"
    kill $iperf_server_pid
    wait $iperf_server_pid

    draw $tcp_probe_output $iperf_server_port "tcp_window_${server}_${client}_${algo}.svg"
    echo "Picture drawn"
}

run_expirement 1 2 "reno"
