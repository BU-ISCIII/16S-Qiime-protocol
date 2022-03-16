'''
=============================================================
HEADER
=============================================================
INSTITUTION: BU-ISCIII
AUTHOR: Guillermo J. Gorines Cordero
MAIL: guillermo.gorines@urjc.es
VERSION: 0
CREATED: 15-3-2022
REVISED: 
DESCRIPTION: 
    Ad-hoc script to generate a heatmap on each category
INPUT:
    -Number of organisms to include (does not matter if
    number set is bigger than current number of organisms)
OUTPUT:
    Balance of reads obtained in the whole service 
'''
import os
import sys

import pandas
import seaborn as sns
import matplotlib.pyplot as plt

relevant_features = sys.argv[1]

def remove_zero_columns(df):
    """Remove rows that are all 0"""
    
    df_removed = df.loc[:, (df != 0).any(axis=0)]
    
    return df_removed

def get_most_relevant(df, number):
    
    df.loc["Desv"] = df.std()
    df.loc["Mean Desv"] = df.mad()
    df = df[(df.loc["Mean Desv"].nlargest(n=number)).index]
    
    df2 = df.drop(["Desv","Mean Desv"], axis=0)
    
    return df2

# dictionary to associate level and group
level_dict = {"lvl7" : "species",
             "lvl6" : "genera",
             "lvl5" : "gamily",
             "lvl4" : "order",
             "lvl3" : "class",
             "lvl2" : "phyla",
             "lvl1" : "domain"}

# list of suitable directories generated by previous script
dir_list = [
    os.path.realpath(item[0]) for item in os.walk(".") 
    if item[0] != "." 
    and "logs" not in item[0]
    and "lvl_6" not in item[0]
    and "lvl_7" not in item[0]] 

# list of files in previous directories
file_list = []
for folder in dir_list:
    for file in os.listdir(folder):
        file_list.append(f"{folder}/{file}")

# for each file, generate the df
# remove empty columns
# get the N most relevant features

for file in file_list[0:1]:
    df = pandas.read_csv(file, sep="\t", header=0, index_col=0)
    df = remove_zero_columns(df)
    df = get_most_relevant(df,10)
    
    category, level = os.path.basename(file).replace(".tsv","").split("_")
    level = level_dict[level]
    png_name = f"{level}_{category}.png"
    
    # dict to rename index
    dict_rename_index = {item:item.split("_")[-1] for item in df.index}
    df.rename(index=dict_rename_index, inplace=True)

    # dict to rename columns
    dict_rename_taxa = {item:item.split("_")[-1] for item in df.columns}
    df.rename(columns=dict_rename_taxa, inplace=True)

    fig,ax = plt.subplots(figsize=(15,15))
    sns.set(rc={'axes.facecolor':'white', 'figure.facecolor':'white'})
    ax.set_title(f"Abundance (% of samples) of organism {level} by {category}", fontdict={'fontsize' : 15})
    sns.heatmap(df, annot=True, 
                cbar=True, 
                cmap="Greens", 
                vmax=100, 
                vmin=0, 
                fmt="g", 
                square=True, 
                ax=ax, 
                cbar_kws={
                    "orientation" : "horizontal",
                    "location" : "top"
                }
            )
    plt.yticks(rotation=0)
    plt.xticks(rotation=45)
    plt.savefig(png_name)