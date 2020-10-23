import dash
import dash_bootstrap_components as dbc
import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output, State

from datetime import datetime
import re
#import numpy as np
#import pandas as pd
#import plotly.graph_objs as go

app = dash.Dash(name=__name__, external_stylesheets=[dbc.themes.BOOTSTRAP])

form_max_length = 256

content = [
    html.H3("USyd Business Analytics Forecast Competition"),
    html.P("Current time: {}".format(datetime.now().strftime(format="%c"))),
    html.P("Forecasts are to be submitted on Fridays between 00:00 and 23:59."),
    dbc.FormGroup(
        [
            dbc.Label("Name", html_for="input-name"),
            dbc.Input(
                id="input-name",
                placeholder="Enter name",
                maxLength=form_max_length,
            ),
            dbc.FormText("Allowed characters: A-Za-z',-<space>"),
        ]
    ),
    dbc.FormGroup(
        [
            dbc.Label("Student No", html_for="input-snumber"),
            dbc.Input(
                id="input-snumber",
                placeholder="Enter student no",
                maxLength=form_max_length,
            ),
            dbc.FormText("Nine numeric digits, no spaces"),
        ]
    ),
    dbc.FormGroup(
        [
            dbc.Label("Forecasts", html_for="input-forecasts"),
            dbc.Input(
                id="input-forecasts",
                placeholder="Enter forecasts",
                maxLength=form_max_length,
            ),
            dbc.FormText("Seven floating point numbers, comma-separated"),
        ]
    ),
    dbc.Button(
        "Submit",
        id="submit-button"
    ),
    html.P(
        id="submit-feedback"
    ),
    html.P(
        id="submit-echo"
    ),
]

def err_tuple(msg):
    return False, False, False, msg, ""

def ok_tuple(msg, echo):
    return True, True, True, msg, echo


@app.callback(
    [
        Output("input-name", "disabled"),
        Output("input-snumber", "disabled"),
        Output("input-forecasts", "disabled"),
        Output("submit-feedback", "children"),
        Output("submit-echo", "children"),
    ],
    [
        Input("submit-button", "n_clicks"),
    ],
    [
        State("input-name", "value"),
        State("input-snumber", "value"),
        State("input-forecasts", "value"),
    ]
)
def update_output(n_clicks, name, snumber, forecasts):

    if not n_clicks:
        msg = ""
        return err_tuple(msg)

    if not name:
        msg = "Required: Name"
        return err_tuple(msg)
        
    if not snumber:
        msg = "Required: Student No"
        return err_tuple(msg)

    if not forecasts:
        msg = "Required: Forecasts"
        return err_tuple(msg)

    name = name[0:form_max_length]
    snumber = snumber[0:form_max_length]
    forecasts = forecasts[0:form_max_length]

    if not re.match("[-,\ \'A-Za-z]+$", name):
        msg = "Allowed characters for name: A-Za-z',-<space>."
        return err_tuple(msg)
    
    if not re.match("[0-9]{9}$", snumber):
        msg = "Student No must be 9 digits, with no spaces."
        return err_tuple(msg)
        
    fstrs = forecasts.split(",")
    nf = len(fstrs)
    if nf < 7:
        msg = "Too few forecasts: Expected 7, received {}.".format(nf)
        return err_tuple(msg)
    if nf > 7:
        msg = "Too many forecasts: Expected 7, received {}.".format(nf)
        return err_tuple(msg)

    fcasts = []
    for s in fstrs:
        try:
            fcasts.append(float(s))
        except ValueError:
            msg = "Failed to parse forecast {} as float.".format(s)
            return err_tuple(msg)

    now = datetime.now()
    if not now.strftime("%a") == "Fri":
        msg = "Forecasts are to be submitted on Fridays between 00:00 and 23:59."
        return err_tuple(msg)
    
    msg = "Thank you for submitting your forecasts:"
    date = now.strftime("%Y-%m-%d")
    record = " | ".join([date, snumber, name] + [str(f) for f in fcasts])
    return ok_tuple(msg, record)
    

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
    ),
    style={'padding':10},
)
        
if __name__ == "__main__":
    app.run_server(debug=True)
