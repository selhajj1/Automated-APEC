#!/usr/bin/env python3

import os
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt

list_cases=['rms_backbone', 'rms_cavity']
data=dict()

for case in list_cases:
   data[case]=dict()
   data[case]['values']=list(np.loadtxt(f'{case}.xvg', usecols=1, skiprows=18, dtype=float))
   data[case]['avg']=np.mean(data[case]['values'])

fig,axes = plt.subplots(1,2, figsize=(4*2,1*3), dpi=300)
[[b.set_linewidth(3) for b in ax.spines.values()] for ax in axes.flat]
x_max=200


for ax,case in zip(axes.flat,list_cases):
   ax.plot(data[case]['values'], alpha=1, label=case)
   ax.plot(x_max/2, data[case]['avg'], alpha=1, marker= 'o', markersize=8)

   ax.legend(bbox_to_anchor=(0.58,0.99))

   ax.set_xlim(0,x_max)
   ax.set_ylim(0,0.3)

fig.savefig(f'RMSDs', dpi = 300)



lines=[]
for case in list_cases:
    if case == list_cases[-1]:
        lines.append(f'{case}')
    else:
        lines.append(f'{case}, ')
lines.append('\n')

for i in data[case]:
    lines.append(f'{i}: ')
    for case in list_cases:
        if case == list_cases[-1]:
            lines.append(f'{data[case]["avg"].round(3)}')
        else:
            lines.append(f'{data[case]["avg"].round(3)}, ')
    lines.append('\n')

with open('averages.txt', 'w') as file:
    for line in lines:
        file.write(line)
