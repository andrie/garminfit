from shiny import Inputs, Outputs, Session, App, reactive, render, req, ui
# from shinywidgets import output_widget, reactive_read, register_widget
# import ipyleaflet
# import folium
# import pathlib

import sys
sys.path.append('py')
import turnpoints
import pandas as pd
import matplotlib

app_ui = ui.page_fillable(

    ui.h1("Upload a Garmin FIT file for analysis"),
    ui.input_radio_buttons("source_data", label = "Source", 
                           choices = {"sample": "Sample data", "upload": "Upload a file"}, selected = "sample"),
    ui.panel_conditional(
        "input.source_data == 'upload'", 
        ui.input_file("filename", "Select a FIT file to analyze", accept = ".fit"),
    ),
    ui.layout_columns(
        ui.card(  
                ui.card_header("Card 1 header"),
                # ui.p("Card 1 body"),
                # ui.input_slider("slider", "Slider", 0, 10, 5),
                ui.output_ui("map"),
                ui.output_ui("colormap"),
            ),  
        ui.card(  
                ui.card_header("Card 1 header"),
                # ui.p("Card 1 body"),
                # ui.input_slider("slider", "Slider", 0, 10, 5),
                ui.output_plot("speed_plot"),
            ),   
        col_widths=(6, 6),  
    ),
)


def server(input: Inputs, output: Outputs, session: Session):

    @reactive.Calc
    def file_info():
        if not input.filename():
            return
        return input.filename()[0]["datapath"]
    
    @reactive.Calc
    def file_name():
        if input.source_data() == "sample":
            return "data/paddle_hcc.fit"
        req(input.filename())
        return input.filename()[0]["datapath"]
    
    @reactive.Calc
    def fit_data():
        # req(file_name())
        return turnpoints.read_garmin(file_name())
    
    @reactive.Calc
    def map_object():
        points = fit_data()
        return turnpoints.create_map(points)
    
    @reactive.Calc
    def tps():
        _, _, tp = map_object()
        return tp 
    
    @output
    @render.ui
    def map():
        map, _, _ = map_object()
        return ui.HTML(map._repr_html_())
    
    
    @output
    @render.plot
    def speed_plot():
        import matplotlib
        import datetime
        points_df = fit_data()
        points_df['enhanced_speed'].plot().set_title('Speed (m/s)')
        # add vertical lines for turnpoints
        tps_ = tps()
        for tp in tps_:
            matplotlib.pyplot.axvline(x=tp, color='lightgrey', linestyle='--')

        # compute average speed between turnpoints
        avs = []
        ts = []
        tps_ = pd.DataFrame(data = {"timestamp": tps_})
        tps_['timestamp'] = pd.to_datetime(tps_['timestamp'], utc=True)
        points_df['timestamp'] = pd.to_datetime(points_df['timestamp'], utc=True)

        for i in range(tps_.shape[0]-1):
            ss = points_df[
                (points_df['timestamp'] >= tps_['timestamp'][i]) &
                (points_df['timestamp'] < tps_['timestamp'][i+1])
            ]
            mean_speed = ss.agg({'enhanced_speed': ['mean']}).values[0][0]
            avs.append(mean_speed)
            ts.append(tps_['timestamp'][i])
        ts.append(tps_['timestamp'][i+1])
        avs.append(mean_speed)

        # print(avs)

        # add horizontal lines for average speed between turnpoints
        matplotlib.pyplot.step(ts, avs, where='post', color = "b", linestyle='-')
        return None


app = App(app_ui, server)
