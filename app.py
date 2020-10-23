import dash
import dash_bootstrap_components as dbc
import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output

from datetime import datetime
import re
#import numpy as np
#import pandas as pd
#import plotly.graph_objs as go

app = dash.Dash(name=__name__, external_stylesheets=[dbc.themes.BOOTSTRAP])

now = datetime.now()

content = [
    html.H3("Business Analytics Forecast Competition"),
    html.P("Current time: {}".format(now.strftime(format="%c"))),
    
    dbc.FormGroup(
        [
            dbc.Label("Name", html_for="input-name"),
            dbc.Input(id="input-name", placeholder="Enter name"),
            dbc.FormFeedback("OK", valid=True),
            dbc.FormFeedback("Invalid", valid=False),
        ]
    ),
    dbc.FormGroup(
        [
            dbc.Label("Student No", html_for="input-snumber"),
            dbc.Input(id="input-snumber", placeholder="Enter student no"),
            dbc.FormText("9 numeric digits, no spaces"),
            dbc.FormFeedback("OK", valid=True),
            dbc.FormFeedback("Invalid", valid=False),
        ]
    ),
    dbc.FormGroup(
        [
            dbc.Label("Forecasts", html_for="input-forecasts"),
            dbc.Input(id="input-forecasts", placeholder="Enter forecasts"),
            dbc.FormText("Seven floating point numbers, comma-separated"),
            dbc.FormFeedback("OK", valid=True),
            dbc.FormFeedback("Invalid", valid=False),
        ]
    ),
]

@app.callback(
    [Output("input-name", "valid"), Output("input-name", "invalid")],
    [Input("input-name", "value")],
)
def check_validity(text):
    if not text:
        return False, False
    ret = bool(text)
    return ret, not ret


@app.callback(
    [Output("input-snumber", "valid"), Output("input-snumber", "invalid")],
    [Input("input-snumber", "value")],
)
def check_validity(text):
    if not text:
        return False, False
    ret = bool(re.match('[0-9]{9}$', text))
    return ret, not ret


@app.callback(
    [Output("input-forecasts", "valid"), Output("input-forecasts", "invalid")],
    [Input("input-forecasts", "value")],
)
def check_validity(text):
    if not text:
        return False, False

    strs = text.split(",")
    if len(strs) != 7:
        return False, True
    
    try:
        fcasts = [float(s) for s in strs]
        ret = True
    except ValueError:
        ret = False
        
    return ret, not ret

app.layout = html.Div(
    dbc.Container(
        [
            dbc.Row(
                [
                    dbc.Col(
                        content
                    )
                ]
            )       
        ]
    )
)
        
if __name__ == "__main__":
    app.run_server(debug=True)
