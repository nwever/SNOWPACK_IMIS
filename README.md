# SNOWPACK_IMIS
Workflow to run SNOWPACK on IMIS stations

## Requirements
1. Tested on Ubuntu 24.04
2. [MeteoIO](https://meteoio.slf.ch) library, with a compiled `meteoio_timeseries` available in `$PATH`.
3. [SNOWPACK](https://snowpack.slf.ch), with compiled `snowpack` available in `$PATH`.
4. (optional) for parallelization, install [`GNU parallel`](https://www.gnu.org/software/parallel)


## Downloading station data

To download the IMIS station data, the script `get_IMIS_station_data.sh` can be used.

1. In the Settings section of the script, adjust:
     - `stnlst`: list of IMIS stations. For example: `stnlst="WFJ2 DAV2"`. `stnlst=""` would download data for all available IMIS stations.
     - `get_live_data`: `1`: download historical + live data. `0`: download historical data only.
2. Run the script: `bash get_IMIS_station_data.sh` to download the IMIS station data and convert it to `smet` files. Run it as: `bash get_IMIS_station_data.sh full` to merge existing processed data as well. This can be practical, since live data doesn't always follow directly on historical data. This can result in data gaps, that can be filled at a later stage when the historical data gets updated on the SLF server. Providing `ful as command line parameter merges the 3 data sources: (1) processed data in the `./smet/` folder, (2) downloaded historical data and (3) downloaded live data.


The Swiss setup uses some station data from [MeteoSwiss](https://meteoswiss.ch). For example, some drift stations are MeteoSwiss-operated stations.

3. Run the script: `bash get_MCH_station_data.sh`: Note that this can currently only be done from within the SLF network. However, all MeteoSwiss data is open-access. So in the nearby future, this script will be rewritten to obtain the MeteoSwiss station data directly from MeteoSwiss.

## Setup SNOWPACK simulations

The script `prepare_snowpack.sh` can be used to setup the SNOWPACK simulations. It generates initial `sno` files, and configuration files.

In the header of the script, the following can be configured:
```
startSeason=2000        # startSeason and endSeason. Note that by definition, the season is denoted by the year it ends. Thus 2023 is season 2022-2023.
endSeason=2025
soil=1                  # 0: no soil, 1: soil
drift_station=1         # 0: no drift stations, 1: use drift station setup
TIMEOUT="timeout 3600"  # Leave empty for no timeout, 3600 means runtime limited to max 1 hour.
```

Notes:
- Since this setup aims to mimick the operational Swiss setup, by default 4 virtual slopes are configured (a N, E, S, and W-facing, 38&deg;).
- The simulations are split by year, with the following year continuing from the output `sno` file from the previous year. The simulations run from September 1 - September 1 in the following year.
- The script does some basic checking if meteo data is available. If no meteo data is available from before 1 September of a specific year, that year is skipped. Also if the end date of the available meteo data is before September 1 of a specific year, that year is skipped.
- The script produces a list `to_run.lst` with the SNOWPACK simulations set up for one specific station per line.

## Run SNOWPACK
Either in serial:
`bash to_run.lst`

or in parallel:
`parallel < to_run.lst`


## Checking the simulations
To do some basic checking of the status of the simulations, the script `check_simulations.sh` can be used. It checkes if the line `FINISHED running SLF RESEARCH Snowpack Model` is present in the log file.
