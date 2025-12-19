#!/usr/bin/env bash


func() {
    declare -a arr=("first" "second")

    # echo "${arr[@]}"
    (local IFS=","; echo "${arr[@]}")
}

func