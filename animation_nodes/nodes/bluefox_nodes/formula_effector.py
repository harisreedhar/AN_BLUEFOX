import bpy
import numpy
from math import *
from bpy.props import *
from ... base_types import AnimationNode
from ... data_structures import *
from ... events import propertyChanged
from..falloff.custom_falloff import CustomFalloff

class Formulafalloff(bpy.types.Node, AnimationNode):
    bl_idname = "an_Formulafalloff"
    bl_label = "Formula falloff"
    errorHandlingType = "EXCEPTION"

    def create(self):
        self.newInput("Integer", "count", "count", value = 1.0, minValue = 0)
        self.newInput("Text", "Formula", "formula", value = "a*(sin(((id / count) + t) * f * 360.0))", update = propertyChanged) 
        self.newInput("Float", "t-Time", "time", value = 0.1)      
        self.newInput("Float", "f-frequency", "f", value = 0.01)
        self.newInput("Float", "a-amplitude", "a", value = 1.0, minValue = 0.00001)
        self.newInput("Boolean", "show variables", "shw", value = 0, hide = True)
        self.newInput("Float", "Fallback", "fallback", hide = True)

        self.newOutput("Falloff", "Falloff", "outFalloff")
        self.newOutput("Float List", "strengths", "strengths")


    def execute(self, count, formula, time, f, a, shw, fallback):
        if shw==1:
            self.raiseErrorMessage("id-index, count-totalamount, f-frequency, t-time, a-amplitude")
        frameinfo=bpy.context.scene.frame_current
        t = frameinfo*time
        out = self.formula_fun(count, formula, t, f, a, fallback)
        falloff_out = CustomFalloff(FloatList.fromValues([0.00]), fallback)
        strength_out = DoubleList.fromValues([0.00])
        try:
            falloff_out = CustomFalloff(FloatList.fromValues(out), fallback)
            strength_out = DoubleList.fromValues(out)
            return falloff_out, strength_out
        except (TypeError, NameError, ValueError, SyntaxError):
            self.raiseErrorMessage("Incorrect formula")
            return falloff_out, strength_out

     
    def formula_fun(self, count, formula, t, f, a, fallback):
        z=[]
        for id in range(count):
            try:
                result = eval(formula) #not safe
            except (TypeError, NameError, ValueError, SyntaxError, AttributeError):
                result=0
                self.raiseErrorMessage("Incorrect formula")
            except ZeroDivisionError:
                result=0
                self.raiseErrorMessage("Division by zero")

            z.append(result)
        return z