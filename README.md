# Intro

Among the highlighted consequences of human-driven climate change, the UN predicts that an increasing frequency and severity of several natural disasters will disproportionately affect disenfranchised and rural communities leading to a surge in displacements of people on a global scale [[1]](#1)[[2]](#2). We start to see this unfold in publicly available data, the *Internal Displacement Monitoring Center* has been tracking internal displacements since 2008. In this timeframe the anually disaplaced people due to natural disasters has averaged around 25 million [[3]](#3).

This project is aimed at creating a simulation model which attempts to predict the number of internal displacement caused by natural disasters under the 5 Shared Socioeconomic Pathways (SSPs) as outlined by the UN [[4]](#4).

In this repository there are 5 code files:
- GIVE_scenarios.jl - julia code for running MimiGIVE simulations by Rennert et. al [[8]](#8) to get the scenario global and country parameters from MimiSSPs [[7]](#7).
- data_exploration.ipynb - Descriptive data analysis of EMDAT and WRI
- parameter_estimation.ipynb - Estimating and saving distributional and model parameters used in the simulation
- model.ipynb - The simulation model. Can be run for all simulations and will save the output.
- results.ipynb - Analysis of the saved results from the model.

# Data
- EMDAT [[5]](#5)
Public dataset of natural disasters including durations, magnitudes, location and effects, inventoried since 1988.
- WRI [[6]](#6)
World Risk Index - evaluating the exposure and vulnerability of countries since 2000, based on various socioeconomic indicators and gridded population data.
- MimiSSPs [[7]](#7)
Part of the larger work by Rennert et. al [[8]](#8) in determining the social cost of carbon.

Descriptive data analysis can be seen in **data_exploration.ipynb**

# Parameterization

All the final parameterizations can be found in **parameter_estimation.ipynb**

## Chance of causing Displacement
To determine the chance of a disaster causing displacement, we will use the WRI information on countries in the given year that a disaster strikes, the magnitude and duration of the disaster and the population density 
A Principal Component Analysis of the WRI dataset reveals the first component to be representing most of the socioeconomic indicators and the secondth principal component to consists of the different measures of exposure. Based on this information, we remove some highly correlated variables and run a determine an underlying factor model via. Factor Analysis. 

![Storm WRI Factor Model](figures/storm_factoranalysis_withdatapoints.png)

Then we use a k-means clustering to segment the data into three clusters, and we find the proportion of disasters in each clusters that caused displacement.

![Storm K-means Factor Clustering](figures/storm_kmeans.png)

We do this procedure for both storms and floods, as can be seen in *data_exploration.ipynb*

## Disaster Magnitudes and Durations
The findings in *data_exploration.ipynb* and initial testing showed that fitting a single distribution to anything but storm magnitudes was infeasible. So the data has been segmented into floods and storms and into outliers and non-outliers, classifying any measurements that is 1.5 the interquartile range above the third quartile as outliers. The segmentation can be seen below:

![Data Segmentation](figures/Data_segmentation.png)

The variables are investigated for trends, as can be seen in *data_exploration.ipynb* and the variables **Occurence-rate<sub>f<sub>**, **Occurence-rate<sub>s<sub>**, **Magnitude<sub>fo<sub>**, **Magnitude<sub>fn<sub>**, and **Duration<sub>so<sub>** where found to be trending upwards and correlated with the global temperature increase. The rest were seen to be stationary and appropriate distributions were fitted either by region or by country.

Every distribution has their own parameters, they are not shared across distributions, but the subscripts and indicies have been dropped in the notation below for clarity.

### Stationary Parameters
For the stationary parameters it is assumed that they are static and have been inferred with MLE estimators
- Proportion<sub>f</sub> ~ Beta($\alpha, \beta$) for every region
- Proportion<sub>s</sub> ~ Beta($\alpha, \beta$) for every region
- Duration<sub>fo</sub> ~ Weibull($\kappa, \lambda, \theta$) for every region
- Duration<sub>fn</sub> ~ Gamma($\alpha, \beta, \theta$) for every region
- Duration<sub>sn</sub> ~ Gamma($\alpha, \beta, \theta$) for every region
- Magnitude<sub>s</sub> ~ N($\mu,\sigma$) for every region

### Trending Parameters
For the trending parameters, it is assumed that they are a function of T, the global average temperature relative to 1900, and the parameters has been inferred with Bayesian hierarchical models.
- Occurence-rate<sub>f</sub> ~ Poisson($\exp ( \alpha + \beta T ) $) for every country
- Occurence-rate<sub>s</sub> ~ Poisson($\exp ( \alpha + \beta T ) $) for every country
- Magnitude<sub>fo</sub> ~ Weibull($\kappa, \exp ( \lambda T ) $) for every region
- Magnitude<sub>fn</sub> ~ Weibull($\kappa, \exp ( \lambda T ) $) for every region
- Duration<sub>so</sub> ~ Weibull($\kappa, \exp ( \lambda T ) $) for every region

## Disaster Displacement Magnitude
A linear regression model has been trained on all disasters in EMDAT that causes displacement, to predict the percentage of the population that a disaster displaces $0 \leq X \leq 1$, given that we know it will cause displacement. The model is given *Disaster Magnitude*, *Duration* and *Population Density* as predictor variables.

$$X = \beta_0 + \beta_1\text{Magnitude} + \beta_2\text{Duration} + \beta_3\text{Popdens}$$

# Model

Putting everything together in our simulation model, as can be found in **model.ipynb**
1. Load scenario global parameters (T, Year)
2. Load scenario country parameters (GDP, Population, size, wri)
3. For every year:
    1. Update Global Temperature and advance year
    2. For every country:
        1. Update Population and GDP
        2. Calculate occurence-rate<sub>f</sub> ($\lambda_f$) = $\alpha + \beta * T$
        3. Draw flood outlier percentage ($\pi_f$) ~ Beta($\alpha, \beta$)
        4. Draw number of floods ~ Poisson($\lambda_f$)
        5. For every flood:
            1. Draw outlier status ~ Bernoulli($\pi_f$)
            2. If outlier = 1:
                1. Draw magnitude ~ Weibull($\kappa, \exp ( \lambda * T ) $)
                2. Draw duration ~ Weibull($\kappa, \lambda, \theta$)
            3. If outlier = 0:
                1. Draw magnitude ~ Weibull($\kappa, \exp ( \lambda * T ) $)
                2. Draw duration  ~ Gamma($\alpha, \beta, \theta$)
            4. Calculate factors = f(wri, duration, magnitude)
            5. Predict clusters = f(factors)
            6. Draw displacement status ~ Bernoulli(Cluster probability)
            7. if Displacement = 1:
                1. Displacement ~ N($(\beta_0 + \beta_1\text{Magnitude} + \beta_2\text{Duration} + \beta_3\text{Popdens}), 0.0001$)
                2. idp = idp + Displacement
                3. Population = Population - Displacement
                4. Update population density
        6. Calculate occurence-rate<sub>s</sub> ($\lambda_s$) = $\alpha + \beta * T$
        7. Draw storm outlier percentage ($\pi_s$) ~ Beta($\alpha, \beta$)
        8. Draw number of storms ~ Poisson($\lambda_s$)
        9. For every storm:
            1. Draw outlier status ~ Bernoulli($\pi_s$)
            2. If outlier = 1:
                1. Draw duration ~ Weibull($\kappa, \exp ( \lambda * T ) $)
            3. If outlier = 0:
                1. Draw duration  ~ Gamma($\alpha, \beta, \theta$)
            4. Draw magnitude ~N($\mu, \sigma$)
            5. Calculate factors = f(wri, duration, magnitude)
            6. Predict clusters = f(factors)
            7. Draw displacement status ~ Bernoulli(Cluster probability)
            8. if Displacement = 1:
                1. Displacement ~ N($(\beta_0 + \beta_1\text{Magnitude} + \beta_2\text{Duration} + \beta_3\text{Popdens}), 0.0001$)
                2. idp = idp + Displacement
                3. Population = Population - Displacement
                4. Update population density

# Results
I did not manage to run the simulation for the highest temperature scenario

The results can be viewed in notebook **results.ipynb** where a number of graphs, static and interactive can be explored. Below is an excerpt showing the number of disasters and the number of internally displaced people under the different scenarios.
![Number of Disasters](figures/num_disasters.png)

![Numer of Internally Displaced People](figures/idps.png)

# Discussion
Two major points of contention are immediately evident from the results:

1. Using the extreme value Weibull distribution to fit severities has shown to be unreliable. When we start to scale the parameters with temperature, the distribution becomes unstable and gives unrealisticly high magnitudes, which causes an extremely high number of displacements (more than the entire world's population at some points). I had to remove a lot of datapoints from the simulation due to this error. To get more realistic results, we should fit a more stable distribution and run the simulations again.

2. The results show an explosive growth in the number of disasters and the number of displaced people as the temperature rises. The growth was far more severe than I would have expected. This is also why I couldn't run the simulation for the highest temperature scenario, as the runtime was 40 hours+. While we may have caught the correlation shown in the data, there are some known problems with the accuracy of the EM-DAT database [[9]](#9), and while the increasing frequencies and magnitudes due to climate change are generally agreed upon, the sharp increase in occurences of natural disasters has been argued to be largely attributed to better recording of natural disasters in recent years [[10]](#10).

# Conclusion
The model in this repository is capable of predicting where natural disasters will strike under different scenarios for climate change. Disaster data is difficult to generalize. The number of datapoints available are still rather few, as we are primarily interested in determining extreme outlier events, and there is a definite difference in the climatic conditions between regions and countries, that makes it difficult to aggregate datapoints beyond a regional scale. Furthermore, as the temperature increases to rise we are headed for climatic conditions that we have not previously recorded to the same level of accuracy as we have in the last 30 years. So the correlations and distributions inferred in this project, and thus the results as well, should be heavily doubted. But, disregarding the uncertainty about predictions for the future, it is evident from this project, and supported by the statements of climate change experts, that natural disasters are increasing in frequency and magnitude, and that the effects of this will disproportionally affect specific countries and communities.

## References
<a id="1">[1]</a> 
U. Nations, 
‘Causes and Effects of Climate Change’, United Nations. 
Accessed: Dec. 23, 2023. [Online]. 
Available: https://www.un.org/en/climatechange/science/causes-effects-climate-change

<a id="2">[2]</a> 
Ian Fry,
‘“Intolerable tide” of people displaced by climate change: UN expert’, OHCHR. 
Accessed: Dec. 23, 2023. [Online]. 
Available: https://www.ohchr.org/en/press-releases/2022/06/intolerable-tide-people-displaced-climate-change-un-expert

<a id="3">[3]</a> 
‘Global Internal Displacement Database’, 
IDMC - Internal Displacement Monitoring Centre. 
Accessed: Dec. 23, 2023. [Online]. 
Available: https://www.internal-displacement.org/database/displacement-data

<a id="4">[4]</a> 
K. Riahi, D. P. van Vuuren, E. Kriegler, and B. O’Neill,
‘The Shared Socio‐Economic Pathways (SSPs): An Overview’, [Online]. 
Available: https://unfccc.int/sites/default/files/part1_iiasa_rogelj_ssp_poster.pdf

<a id="5">[5]</a> 
‘EM-DAT - The international disaster database’. 
Accessed: Dec. 23, 2023. [Online]. 
Available: https://www.emdat.be/

<a id="6">[6]</a> 
‘WeltRisikoBericht’, 
WeltRisikoBericht. 
Accessed: Dec. 23, 2023. [Online]. 
Available: https://weltrisikobericht.de/en/

<a id="7">[7]</a> 
‘anthofflab/MimiSSPs.jl’. 
The Society, Environment and Economics Lab,
Feb. 09, 2023. 
Accessed: Dec. 23, 2023. [Online]. 
Available: https://github.com/anthofflab/MimiSSPs.jl

<a id="8">[8]</a> 
K. Rennert et al.,
‘Comprehensive evidence implies a higher social cost of CO2’, 
Nature, vol. 610, no. 7933, pp. 687–692, 
Oct. 2022, 
doi: 10.1038/s41586-022-05224-9.

<a id="9">[9]</a> 
D. Guha-Sapir and R. Below, 
The Quality and Accuracy of Disaster Data: A Comparative Analyses of Three Global Data Sets. 
2000.

<a id="10">[10]</a> 
G. Alimonti and L. Mariani, 
‘Is the number of global natural disasters increasing?’, 
Environmental Hazards, vol. 0, no. 0, pp. 1–17, 2023, 
doi: 10.1080/17477891.2023.2239807.



