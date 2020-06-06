#!/usr/bin/env bash

set -e

./ectool.sh info
sudo modprobe msr

header=1
if [ -e power.csv ]
then
    header=0
fi

has_dgpu=0
if nvidia-smi &> /dev/null
then
    has_dgpu=1
fi

while true
do
    if [ "${header}" == "1" ]
    then
        F="Time    "
        F="${F}\tBAT W"
        F="${F}\tCPU W"
        F="${F}\tCPU PL1"
        F="${F}\tCPU PL2"
        F="${F}\tCPU C"
        F="${F}\tCPU TCC"
        F="${F}\tCPU TJM"
        F="${F}\tCPU FAN"
        if [ "${has_dgpu}" == "1" ]
        then
            F="${F}\tGPU W"
            F="${F}\tGPU C"
            F="${F}\tGPU FAN"
        fi
    else
        F="$(date "+%T")"

        last_E="$(cat /sys/class/powercap/intel-rapl\:0/energy_uj)"
        sleep 1

        uV="$(cat /sys/class/power_supply/BAT0/voltage_now)"
        V="$(echo "${uV}/1000000" | bc -lq)"
        uA="$(cat /sys/class/power_supply/BAT0/current_now)"
        A="$(echo "${uA}/1000000" | bc -lq)"
        bat_W="$(echo "${V} * ${A}" | bc -lq)"
        F="${F}\t$(printf "%.2f" "${bat_W}")"

        E="$(cat /sys/class/powercap/intel-rapl\:0/energy_uj)"
        W="$(echo "(${E} - ${last_E})/1000000" | bc -lq)"
        F="${F}\t$(printf "%.1f" "${W}")"

        PL1_uW="$(cat /sys/class/powercap/intel-rapl\:0/constraint_0_power_limit_uw)"
        PL1_W="$(echo "${PL1_uW}/1000000" | bc -lq)"
        F="${F}\t$(printf "%.1f" "${PL1_W}")"

        PL2_uW="$(cat /sys/class/powercap/intel-rapl\:0/constraint_1_power_limit_uw)"
        PL2_W="$(echo "${PL2_uW}/1000000" | bc -lq)"
        F="${F}\t$(printf "%.1f" "${PL2_W}")"

        T="$(cat /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)"
        C="$(echo "${T}/1000" | bc -lq)"
        F="${F}\t$(printf "%.1f" "${C}")"

        TJMAX="$(sudo rdmsr -c 0x1A2 --bitfield 23:16)"
        TCC_OFF="$(sudo rdmsr -c 0x1A2 --bitfield 31:24)"
        TCC="$(python3 -c "print(hex(${TJMAX}-${TCC_OFF}))")"
        F="${F}\t$(printf "%d" "${TCC}")"
        F="${F}\t$(printf "%d" "${TJMAX}")"

        D="$(sudo tool/target/release/system76_ectool fan 0)"
        P="$(echo "(${D} * 100)/255" | bc -lq)"
        F="${F}\t$(printf "%.0f" "${P}")"

        if [ "${has_dgpu}" == "1" ]
        then
            DGPU_W="$(nvidia-smi --query-gpu=power.draw --format=csv,noheader | cut -d' ' -f1)"
            F="${F}\t$(printf "%.1f" "${DGPU_W}")"

            DGPU_T="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)"
            F="${F}\t${DGPU_T}"

            D="$(sudo tool/target/release/system76_ectool fan 1)"
            P="$(echo "(${D} * 100)/255" | bc -lq)"
            F="${F}\t$(printf "%.0f" "${P}")"
        fi
    fi

    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq
    do
        if [ "${header}" == "1" ]
        then
            id="$(basename "$(dirname "$(dirname "${file}")")")"
            F="${F}\t${id}"
        else
            KHz="$(cat "${file}")"
            MHz="$(echo "${KHz}/1000" | bc -lq)"
            F="${F}\t$(printf "%.0f" "${MHz}")"
        fi
    done

    echo -e "${F}" | tee -a power.csv

    header=0
done
