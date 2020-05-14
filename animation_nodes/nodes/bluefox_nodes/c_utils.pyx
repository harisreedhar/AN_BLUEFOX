import cython
from ... data_structures cimport (
    DoubleList, FloatList,VirtualMatrix4x4List,
    Vector3DList, EulerList, Matrix4x4List,
    VirtualVector3DList, VirtualEulerList, VirtualFloatList, VirtualDoubleList,
    Action, ActionEvaluator, PathIndexActionChannel,
    BoundedAction, BoundedActionEvaluator,Color,
    ColorList, PolygonIndicesList, IntegerList, PolySpline, BezierSpline, Interpolation
)
from ... math cimport (
    Vector3, Euler3, Matrix4, toMatrix4,toVector3,
    multMatrix4, toPyMatrix4,
    invertOrthogonalTransformation,
    setTranslationRotationScaleMatrix,
    setRotationXMatrix, setRotationYMatrix, setRotationZMatrix,
    setRotationMatrix, setTranslationMatrix, setIdentityMatrix,
    setScaleMatrix,
    setMatrixTranslation,
    transposeMatrix_Inplace)
from..matrix.c_utils import* 
from mathutils import Matrix, Euler, Vector
from ... nodes.number.c_utils import range_DoubleList_StartStop, mapRange_DoubleList_Interpolated 
from ... algorithms.random import getRandom3DVector
from ... algorithms.random import uniformRandomDoubleWithTwoSeeds
from ... math cimport abs as absNumber
from ... math import matrix4x4ListToEulerList
from ... math cimport (add, subtract, multiply, divide_Save, modulo_Save,
                       sin, cos, tan, asin_Save, acos_Save, atan, atan2, hypot,
                       power_Save, floor, ceil, sqrt_Save, invert, reciprocal_Save,
                       snap_Save, copySign, floorDivision_Save, logarithm_Save)
from libc.math cimport sqrt
from libc.math cimport M_PI as PI
from ... algorithms.lists.random import generateRandomVectors

def matrixlerp(Matrix4x4List matricesA, Matrix4x4List matricesB, DoubleList influences):
    cdef Py_ssize_t count = max(matricesA.getLength(),matricesB.getLength())
    cdef Py_ssize_t i
    cdef Matrix4x4List out_matrixlist = Matrix4x4List(length = count)
    cdef VirtualMatrix4x4List matrixlistA = VirtualMatrix4x4List.create(matricesA, Matrix.Identity(4))
    cdef VirtualMatrix4x4List matrixlistB = VirtualMatrix4x4List.create(matricesB, Matrix.Identity(4))
    cdef VirtualDoubleList influencess = VirtualDoubleList.create(influences, 0)

    for i in range(count):
        out_matrixlist[i]= matrixlistA[i] . lerp( matrixlistB[i], influencess[i] )  
    return out_matrixlist
 
def getTextureColors_moded(texture, Vector3DList locations, float multiplier):
    cdef long amount = locations.length
    cdef DoubleList reds = DoubleList(length = amount)
    cdef DoubleList greens = DoubleList(length = amount)
    cdef DoubleList blues = DoubleList(length = amount)
    cdef DoubleList alphas = DoubleList(length = amount)
    cdef ColorList colors = ColorList(length = amount)
    cdef float r, g, b, a

    for i in range(amount):
        r, g, b, a = texture.evaluate(locations[i])
        reds.data[i] = r*multiplier
        greens.data[i] = g*multiplier
        blues.data[i] = b*multiplier
        alphas.data[i] = a*multiplier
        colors.data[i] = Color(r, g, b, a)
    return colors, reds, greens, blues, alphas

def getTexturegreys(texture, Vector3DList locations, float multiplier):
    cdef long amount = locations.length
    cdef DoubleList greys = DoubleList(length = amount)
    cdef float r, g, b, a

    for i in range(amount):
        r, g, b, a = texture.evaluate(locations[i])
        greys.data[i] = ((r+g+b)/3)*multiplier
    return greys 
      
def matrix_lerp(Matrix4x4List mA, Matrix4x4List mB, DoubleList influences):
    cdef Vector3DList tA = extractMatrixTranslations(mA)
    cdef Vector3DList tB = extractMatrixTranslations(mB)
    cdef EulerList rA = extractMatrixRotations(mA)
    cdef EulerList rB = extractMatrixRotations(mB)
    cdef Vector3DList sA = extractMatrixScales(mA)
    cdef Vector3DList sB = extractMatrixScales(mB)
    cdef int count = max(mA.getLength(), mB.getLength())
    cdef VirtualVector3DList translations_out = VirtualVector3DList.create(tA, (0, 0, 0))
    cdef VirtualEulerList rotations_out = VirtualEulerList.create(rA, (0, 0, 0))
    cdef VirtualVector3DList scales_out = VirtualVector3DList.create(sA, (1, 1, 1))
    for i in range(count):
        translations_out.get(i).x = tA.data[i].x * (1-influences.data[i]) + tB.data[i].x * influences.data[i]
        translations_out.get(i).y = tA.data[i].y * (1-influences.data[i]) + tB.data[i].y * influences.data[i]
        translations_out.get(i).z = tA.data[i].z * (1-influences.data[i]) + tB.data[i].z * influences.data[i]
        rotations_out.get(i).x = rA.data[i].x * (1-influences.data[i]) + rB.data[i].x * influences.data[i]
        rotations_out.get(i).y = rA.data[i].y * (1-influences.data[i]) + rB.data[i].y * influences.data[i]
        rotations_out.get(i).z = rA.data[i].z * (1-influences.data[i]) + rB.data[i].z * influences.data[i]
        scales_out.get(i).x = sA.data[i].x * (1-influences.data[i]) + sB.data[i].x * influences.data[i]
        scales_out.get(i).y = sA.data[i].y * (1-influences.data[i]) + sB.data[i].y * influences.data[i]
        scales_out.get(i).z = sA.data[i].z * (1-influences.data[i]) + sB.data[i].z * influences.data[i]      
    return composeMatrices(count, translations_out, rotations_out, scales_out)

def vector_lerp(Vector3DList vectorsA, Vector3DList vectorsB, DoubleList influences):
    cdef Py_ssize_t count = max(vectorsA.getLength(), vectorsB.getLength())
    cdef Py_ssize_t i
    cdef Vector3DList out_vectorlist = Vector3DList(length = count)
    for i in range(count):
        out_vectorlist.data[i].x = vectorsA.data[i].x * (1-influences.data[i]) + vectorsB.data[i].x * influences.data[i]
        out_vectorlist.data[i].y = vectorsA.data[i].y * (1-influences.data[i]) + vectorsB.data[i].y * influences.data[i]
        out_vectorlist.data[i].z = vectorsA.data[i].z * (1-influences.data[i]) + vectorsB.data[i].z * influences.data[i]
    return out_vectorlist

def euler_lerp(EulerList eulersA, EulerList eulersB, DoubleList influences):
    cdef Py_ssize_t count = max(eulersA.getLength(), eulersB.getLength())
    cdef Py_ssize_t i
    cdef EulerList out_eulerlist = EulerList(length = count)
    for i in range(count):
        out_eulerlist.data[i].x = eulersA.data[i].x * (1-influences.data[i]) + eulersB.data[i].x * influences.data[i]
        out_eulerlist.data[i].y = eulersA.data[i].y * (1-influences.data[i]) + eulersB.data[i].y * influences.data[i]
        out_eulerlist.data[i].z = eulersA.data[i].z * (1-influences.data[i]) + eulersB.data[i].z * influences.data[i]
    return out_eulerlist

def generateRandomColors(Py_ssize_t count, Py_ssize_t seed, float scale, bint normalized):
    cdef Py_ssize_t i
    cdef Vector3DList randomVectors = generateRandomVectors(seed, count, scale, normalized)
    cdef ColorList colors = ColorList(length = count)
    for i in range(count):
        r = absNumber(randomVectors.data[i].x)
        g = absNumber(randomVectors.data[i].y)
        b = absNumber(randomVectors.data[i].z)
        colors.data[i] = Color(r, g, b, 1)
    return colors  

def inheritanceCurveOld(Vector3DList vA, Vector3DList vB, Vector3DList pathPoints, float varMin, float varMax, 
                            float randomScale, float smoothness, DoubleList influences, resolution):

    cdef Py_ssize_t i, j
    cdef Py_ssize_t count = vA.getLength()
    cdef Py_ssize_t pathCount = pathPoints.getLength()
    cdef float parameter, newParameter, randomNumber
    cdef Vector3 v
    cdef Vector3DList newPoints = Vector3DList(length = count)
    cdef FloatList radii =  FloatList(length = pathCount + 2)
    cdef FloatList tilts =  FloatList(length = pathCount + 2)
    cdef Vector3DList handles = Vector3DList(length = pathCount + 2)
    cdef Vector3DList randomVectors = generateRandomVectors(1, count, randomScale, False)
    radii.fill(0)
    tilts.fill(0)
    handles.fill([0,0,0])

    for i in range(count):
        newSplinePoints = Vector3DList()
        newSplinePoints.append(vA[i])
        for j in range(pathCount):
            v.x = pathPoints.data[j].x + randomVectors.data[i].x
            v.y = pathPoints.data[j].y + randomVectors.data[i].y
            v.z = pathPoints.data[j].z + randomVectors.data[i].z
            newSplinePoints.append(Vector((v.x, v.y, v.z)))
        newSplinePoints.append(vB[i])
        if smoothness == 0:
            newSpline = PolySpline(newSplinePoints, radii, tilts, False)
        else:    
            newSpline = BezierSpline(newSplinePoints, handles, handles, radii, tilts, False)
            newSpline.smoothAllHandles(smoothness)
        newSpline.ensureUniformConverter(resolution)
        randomNumber = uniformRandomDoubleWithTwoSeeds(i, 0, varMin, varMax)
        parameter = (1.0 + randomNumber) * influences[i]
        newParameter = min(max(parameter, 0), 1)
        newParameter = newSpline.toUniformParameter(newParameter)
        newPoints[i] = newSpline.evaluatePoint(newParameter)
    return newPoints 

def stepEffector(Matrix4x4List matrices, Vector3DList v, EulerList e, Vector3DList s, DoubleList influences, 
                        Interpolation interpolation, double minValue, double maxValue, bint clamp):
    cdef Vector3DList tA = extractMatrixTranslations(matrices)
    cdef EulerList rA = extractMatrixRotations(matrices)
    cdef Vector3DList sA = extractMatrixScales(matrices)
    cdef int count = matrices.getLength()
    cdef double varMin = 0, varMax = 1
    if not clamp:
        varMin = minValue
        varMax = maxValue   
    cdef DoubleList strengths = range_DoubleList_StartStop(count, 0.00, 1.00)
    cdef DoubleList interpolatedStrengths = mapRange_DoubleList_Interpolated(strengths, interpolation, 0, 1, varMin, varMax)
    cdef VirtualVector3DList translations_out = VirtualVector3DList.create(tA, (0, 0, 0))
    cdef VirtualEulerList rotations_out = VirtualEulerList.create(rA, (0, 0, 0))
    cdef VirtualVector3DList scales_out = VirtualVector3DList.create(sA, (1, 1, 1))
    for i in range(count):
        strength = interpolatedStrengths.data[i]
        if clamp:
            translations_out.get(i).x = tA.data[i].x + max(min(influences.data[i] * v.data[0].x * strength, maxValue), minValue)
            translations_out.get(i).y = tA.data[i].y + max(min(influences.data[i] * v.data[0].y * strength, maxValue), minValue)
            translations_out.get(i).z = tA.data[i].z + max(min(influences.data[i] * v.data[0].z * strength, maxValue), minValue)
            rotations_out.get(i).x = rA.data[i].x + max(min(influences.data[i] * e.data[0].x * strength, maxValue), minValue)
            rotations_out.get(i).y = rA.data[i].y + max(min(influences.data[i] * e.data[0].y * strength, maxValue), minValue)
            rotations_out.get(i).z = rA.data[i].z + max(min(influences.data[i] * e.data[0].z * strength, maxValue), minValue)
            scales_out.get(i).x = sA.data[i].x + max(min(influences.data[i] * s.data[0].x * strength, maxValue), minValue)
            scales_out.get(i).y = sA.data[i].y + max(min(influences.data[i] * s.data[0].y * strength, maxValue), minValue) 
            scales_out.get(i).z = sA.data[i].z + max(min(influences.data[i] * s.data[0].z * strength, maxValue), minValue)
        else:
            translations_out.get(i).x = tA.data[i].x + influences.data[i] * v.data[0].x * strength
            translations_out.get(i).y = tA.data[i].y + influences.data[i] * v.data[0].y * strength
            translations_out.get(i).z = tA.data[i].z + influences.data[i] * v.data[0].z * strength
            rotations_out.get(i).x = rA.data[i].x + influences.data[i] * e.data[0].x * strength
            rotations_out.get(i).y = rA.data[i].y + influences.data[i] * e.data[0].y * strength
            rotations_out.get(i).z = rA.data[i].z + influences.data[i] * e.data[0].z * strength
            scales_out.get(i).x = sA.data[i].x + influences.data[i] * s.data[0].x * strength
            scales_out.get(i).y = sA.data[i].y + influences.data[i] * s.data[0].y * strength 
            scales_out.get(i).z = sA.data[i].z + influences.data[i] * s.data[0].z * strength          
    return composeMatrices(count, translations_out, rotations_out, scales_out), interpolatedStrengths           

def inheritanceCurveVector(Vector3DList vA, Vector3DList vB, Vector3DList splinePoints, float randomScale, DoubleList influences):
    cdef Py_ssize_t i, j, bIndex, aIndex
    cdef Py_ssize_t count = vA.getLength()
    cdef Py_ssize_t splinePointCount = splinePoints.getLength()
    cdef Py_ssize_t innerLength = splinePointCount + 2
    cdef double f, influence
    cdef Vector3DList out_vectorlist = Vector3DList(length = count)
    cdef Vector3DList innerVectorList = Vector3DList(length = innerLength)
    cdef Vector3DList randomVectors = generateRandomVectors(1, count, randomScale, False)
    for i in range(count):
        innerVectorList.data[0] = vA.data[i]
        for j in range(splinePointCount):
            innerVectorList.data[j+1].x = splinePoints.data[j].x + randomVectors.data[i].x
            innerVectorList.data[j+1].y = splinePoints.data[j].y + randomVectors.data[i].y
            innerVectorList.data[j+1].z = splinePoints.data[j].z + randomVectors.data[i].z
        innerVectorList.data[innerLength - 1] = vB.data[i]
        f = influences.data[i] * (innerLength - 1)
        influence = f % 1 
        bIndex = int(max(min(floor(f), innerLength - 1), 0))
        aIndex = int(max(min(ceil(f), innerLength - 1), 0))
        out_vectorlist.data[i].x = innerVectorList.data[bIndex].x * (1-influence) + innerVectorList.data[aIndex].x * influence
        out_vectorlist.data[i].y = innerVectorList.data[bIndex].y * (1-influence) + innerVectorList.data[aIndex].y * influence
        out_vectorlist.data[i].z = innerVectorList.data[bIndex].z * (1-influence) + innerVectorList.data[aIndex].z * influence
    return out_vectorlist

def inheritanceCurveEuler(EulerList eA, EulerList eB, EulerList splineEulers, DoubleList influences):
    cdef Py_ssize_t i, j, bIndex, aIndex
    cdef Py_ssize_t count = eA.getLength()
    cdef Py_ssize_t splineEulerCount = splineEulers.getLength()
    cdef Py_ssize_t innerLength = splineEulerCount + 2
    cdef double f, influence
    cdef EulerList outEulerlist = EulerList(length = count)
    cdef EulerList innerEulerList = EulerList(length = innerLength)
    for i in range(count):
        innerEulerList.data[0] = eA.data[i]
        for j in range(splineEulerCount):
            innerEulerList.data[j+1].x = splineEulers.data[j].x
            innerEulerList.data[j+1].y = splineEulers.data[j].y
            innerEulerList.data[j+1].z = splineEulers.data[j].z
        innerEulerList.data[innerLength - 1] = eB.data[i]
        f = influences.data[i] * (innerLength - 1)
        influence = f % 1 
        bIndex = int(max(min(floor(f), innerLength - 1), 0))
        aIndex = int(max(min(ceil(f), innerLength - 1), 0))
        outEulerlist.data[i].x = innerEulerList.data[bIndex].x * (1-influence) + innerEulerList.data[aIndex].x * influence
        outEulerlist.data[i].y = innerEulerList.data[bIndex].y * (1-influence) + innerEulerList.data[aIndex].y * influence
        outEulerlist.data[i].z = innerEulerList.data[bIndex].z * (1-influence) + innerEulerList.data[aIndex].z * influence
    return outEulerlist    

def inheritanceCurveMatrix(Matrix4x4List mA, Matrix4x4List mB, Vector3DList splinePoints, EulerList splineEulers, float randomScale, DoubleList influences, bint align):
    cdef Vector3DList tA = extractMatrixTranslations(mA)
    cdef Vector3DList tB = extractMatrixTranslations(mB)
    cdef EulerList rA = extractMatrixRotations(mA)
    cdef EulerList rB = extractMatrixRotations(mB)
    cdef Vector3DList sA = extractMatrixScales(mA)
    cdef Vector3DList sB = extractMatrixScales(mB)
    cdef int count = max(mA.getLength(), mB.getLength())
    cdef VirtualVector3DList translations_out = VirtualVector3DList.create(tA, (0, 0, 0))
    cdef VirtualEulerList rotations_out = VirtualEulerList.create(rA, (0, 0, 0))
    cdef VirtualVector3DList scales_out = VirtualVector3DList.create(sA, (1, 1, 1))
    cdef Vector3DList translationCurve = inheritanceCurveVector(tA, tB, splinePoints, randomScale, influences)
    cdef EulerList rotationCurve = EulerList()
    if align:
        rotationCurve = inheritanceCurveEuler(rA, rB, splineEulers, influences)
    for i in range(count):
        translations_out.get(i).x = translationCurve.data[i].x
        translations_out.get(i).y = translationCurve.data[i].y
        translations_out.get(i).z = translationCurve.data[i].z
        if align:
            rotations_out.get(i).x = rotationCurve.data[i].x
            rotations_out.get(i).y = rotationCurve.data[i].y
            rotations_out.get(i).z = rotationCurve.data[i].z
        else:
            rotations_out.get(i).x = rA.data[i].x * (1-influences.data[i]) + rB.data[i].x * influences.data[i]
            rotations_out.get(i).y = rA.data[i].y * (1-influences.data[i]) + rB.data[i].y * influences.data[i]
            rotations_out.get(i).z = rA.data[i].z * (1-influences.data[i]) + rB.data[i].z * influences.data[i]    
        scales_out.get(i).x = sA.data[i].x * (1-influences.data[i]) + sB.data[i].x * influences.data[i]
        scales_out.get(i).y = sA.data[i].y * (1-influences.data[i]) + sB.data[i].y * influences.data[i]
        scales_out.get(i).z = sA.data[i].z * (1-influences.data[i]) + sB.data[i].z * influences.data[i]      
    return composeMatrices(count, translations_out, rotations_out, scales_out)