

def curvature(lng, lat):

  def first_diff(x) :
    return [x[i] - x[i-2] for i in range(2, len(x))]
      
  def second_diff(x) :
    return [x[i] - 2 * x[i-1] + x[i-2] for i in range(2, len(x))]

  def range_len(x) :
    return range(len(x))
  
  x  = lng
  y  = lat
  x1 = first_diff(x)
  y1 = first_diff(y)
  x2 = second_diff(x)
  y2 = second_diff(y)
  num = [abs(x1[i] * y2[i] - y1[i] * x2[i]) for i in range_len(x1)]
  denom = [((x1[i]**2 + y1[i]**2)**3)**0.5 for i in range_len(x1)]
  z = [num[i] / denom[i] for i in range(len(num))]
  return [0, z, 0]



def spatial_simplify(x, round_digits = 3):
    x['timestamp'] = x.index
    z = x.assign(
        lonr = lambda x: x['lon'].round(round_digits), 
        latr = lambda x: x['lat'].round(round_digits),
        new_rect = lambda x: (x['lonr'] != x['lonr'].shift(1)).cumsum() 
    ).groupby('new_rect').agg(
        {
            'timestamp': 'max',
            'lon': 'mean',
            'lat': 'mean',
            'enhanced_speed' : 'mean',
            'distance': 'max',
        }
    ).assign(
        distance =  lambda x: x['distance'].diff(),
        speed = lambda x: x['enhanced_speed']
    )
    return z

def read_garmin(filename):
    # sys.path.append('py')
    import parse_fit
    _, points_df = parse_fit.get_dataframes(filename)
    return(points_df)

   

def create_map(points_df, epsilon = 0.001, round_digits = 4):
    from rdp import rdp
    import numpy as np
    import folium
    import branca.colormap as cm
    # simplify points_df
    points_df = spatial_simplify(points_df, round_digits = round_digits)
    # creat map of latitude and longitude in points_df
    mlat = points_df['lat'].mean()
    mlon = points_df['lon'].mean()
    m = folium.Map(location=[mlat, mlon], zoom_start=16, tiles="cartodb positron")

    trail = points_df[['lat', 'lon']].values.tolist()
    quantiles = points_df['enhanced_speed'].quantile([0.025, 1]).round(1).values.tolist()
    speed_colormap = cm.LinearColormap(
       ["red", "yellow", "green"], 
       vmin = quantiles[0], 
       vmax = quantiles[1], 
       caption="speed (m/s)"
    )

    folium.ColorLine(trail, 
                     points_df['enhanced_speed'], weight=4, opacity=1, 
                     colormap=speed_colormap).add_to(m)


    # extract lon and lat from points_df and convert to numpy array
    lat = points_df['lat'].values
    lon = points_df['lon'].values

    # combine lat and lon into array
    arr = points_df[['lat', 'lon']].to_numpy()
    arr.shape

    # compute turnpoints using Ramer-Douglas-Peucker algorithm
    turnpoints_mask = rdp(arr, epsilon = epsilon, return_mask=True)

    # convert turnpoints to list
    turnpoints = arr[turnpoints_mask]


    # add turnpoints as markers to map
    counter = 0
    for i in range(len(turnpoints)):
        counter += 1
        folium.Marker(turnpoints[i], tooltip=counter).add_to(m)
    
    timestamps = points_df['timestamp'].values
    turnpoints = timestamps[turnpoints_mask]

    # scale floium map to fit all points
    m.fit_bounds(m.get_bounds())
    return(m, speed_colormap, turnpoints)
