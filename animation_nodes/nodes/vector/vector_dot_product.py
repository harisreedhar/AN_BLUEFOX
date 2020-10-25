import bpy
from ... base_types import AnimationNode, VectorizedSocket

class VectorDotProductNode(bpy.types.Node, AnimationNode):
    bl_idname = "an_VectorDotProductNode"
    bl_label = "Vector Dot Product"

    useListA: VectorizedSocket.newProperty()
    useListB: VectorizedSocket.newProperty()

    def create(self):
        self.newInput(VectorizedSocket("Vector", "useListA",
            ("A", "a"), ("A", "a")))
        self.newInput(VectorizedSocket("Vector", "useListB",
            ("B", "b"), ("B", "b")))

        self.newOutput(VectorizedSocket("Float", ["useListA", "useListB"],
            ("Dot Product", "dotProduct"), ("Dot Product", "dotProducts")))

    def getExecutionCode(self, required):
        if self.useListA or self.useListB:
            yield "amount = VirtualVector3DList.getMaxRealLength(a, b)"
            yield "_vA, _vB = VirtualVector3DList.createMultiple((a, (0,0,0)), (b, (0,0,0)))"
            yield "dotProducts = AN.nodes.vector.c_utils.calculateVectorDotProducts(amount, _vA, _vB)"
        else:
            yield "dotProduct = a.dot(b)"
