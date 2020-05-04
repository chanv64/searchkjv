#!/bin/bash
gawk '/ Book of / || /^Hosea/ {print}' kjv.txt

