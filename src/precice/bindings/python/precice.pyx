"""precice

The python module precice offers python language bindings to the C++ coupling library precice. Please refer to precice.org for further information.
"""

from cpython       cimport array
from libcpp        cimport bool
from libc.stdlib   cimport free
from libc.stdlib   cimport malloc
from libcpp.set    cimport set
from libcpp.memory cimport shared_ptr
from libcpp.string cimport string
from libcpp.memory cimport unique_ptr
from libcpp.vector cimport vector
from mpi4py import MPI

from cpython.version cimport PY_MAJOR_VERSION  # important for determining python version in order to properly normalize string input. See http://docs.cython.org/en/latest/src/tutorial/strings.html#general-notes-about-c-strings and https://github.com/precice/precice/issues/68 . 

cdef bytes convert(s):
    """
    source code from http://docs.cython.org/en/latest/src/tutorial/strings.html#general-notes-about-c-strings
    """
    if type(s) is bytes:
        return s
    elif type(s) is str:
        return s.encode()
    else:
        raise TypeError("Could not convert.")

cdef extern from "precice/SolverInterface.hpp"  namespace "precice":
   cdef cppclass SolverInterface:
      # construction and configuration

      SolverInterface (const string&, int, int) except +

      void configure (const string&)

      # steering methods

      double initialize ()

      void initializeData ()

      double advance (double computedTimestepLength)

      void finalize()

      # status queries

      int getDimensions() const

      bool isCouplingOngoing()

      bool isReadDataAvailable()

      bool isWriteDataRequired (double computedTimestepLength)

      bool isTimestepComplete()

      bool hasToEvaluateSurrogateModel ()

      bool hasToEvaluateFineModel ()

      # action methods

      bool isActionRequired (const string& action)

      void fulfilledAction (const string& action)

      # mesh access

      bool hasMesh (const string& meshName ) const

      int getMeshID (const string& meshName)

      set[int] getMeshIDs ()

      # MeshHandle getMeshHandle (const string& meshName)

      int setMeshVertex (int meshID, const double* position)

      int getMeshVertexSize (int meshID)

      void setMeshVertices (int meshID, int size, const double* positions, int* ids)

      void getMeshVertices (int meshID, int size, const int* ids, double* positions)

      void getMeshVertexIDsFromPositions (int meshID, int size, double* positions, int* ids)

      int setMeshEdge (int meshID, int firstVertexID, int secondVertexID)

      void setMeshTriangle (int meshID, int firstEdgeID, int secondEdgeID, int thirdEdgeID)

      void setMeshTriangleWithEdges (int meshID, int firstVertexID, int secondVertexID, int thirdVertexID)

      void setMeshQuad (int meshID, int firstEdgeID, int secondEdgeID, int thirdEdgeID, int fourthEdgeID)

      void setMeshQuadWithEdges (int meshID, int firstVertexID, int secondVertexID, int thirdVertexID, int fourthVertexID)

      # data access

      bool hasData (const string& dataName, int meshID) const

      int getDataID (const string& dataName, int meshID)

      void mapReadDataTo (int toMeshID)

      void mapWriteDataFrom (int fromMeshID)

      void writeBlockVectorData (int dataID, int size, int* valueIndices, double* values)

      void writeVectorData (int dataID, int valueIndex, const double* value)

      void writeBlockScalarData (int dataID, int size, int* valueIndices, double* values)

      void writeScalarData (int dataID, int valueIndex, double value)

      void readBlockVectorData (int dataID, int size, int* valueIndices, double* values)

      void readVectorData (int dataID, int valueIndex, double* value)

      void readBlockScalarData (int dataID, int size, int* valueIndices, double* values)

      void readScalarData (int dataID, int valueIndex, double& value)


cdef extern from "precice/SolverInterface.hpp"  namespace "precice::constants":
   const string& actionWriteInitialData()
   const string& actionWriteIterationCheckpoint()
   const string& actionReadIterationCheckpoint()


cdef class Interface:
   cdef SolverInterface *thisptr # hold a C++ instance being wrapped
   
   # construction and configuration
   # constructor

   def __cinit__ (self, solver_name, int solver_process_index, int solver_process_size):
      self.thisptr = new SolverInterface (convert(solver_name), solver_process_index, solver_process_size)
      pass

   # destructor
   def __dealloc__ (self):
      del self.thisptr

   # configure
   def configure (self, configuration_file_name):
      self.thisptr.configure (convert(configuration_file_name))

   # steering methods
   # initialize
   def initialize (self):
      return self.thisptr.initialize ()

   # initialize data
   def initialize_data (self):
      self.thisptr.initializeData ()

   # advance in time
   def advance (self, double computed_timestep_length):
      return self.thisptr.advance (computed_timestep_length)

   # finalize preCICE
   def finalize (self):
      self.thisptr.finalize ()

   # status queries
   # get dimensions
   def get_dimensions (self):
      return self.thisptr.getDimensions ()

   # check if coupling is going on
   def is_coupling_ongoing (self):
      return self.thisptr.isCouplingOngoing ()

   # check if data is available to be read
   def is_read_data_available (self):
      return self.thisptr.isReadDataAvailable ()

   # check if write data is needed
   def is_write_data_required (self, double computed_timestep_length):
      return self.thisptr.isWriteDataRequired (computed_timestep_length)

   # check if time-step is complete
   def is_timestep_complete (self):
      return self.thisptr.isTimestepComplete ()

   # returns whether the solver has to evaluate the surrogate model representation
   def has_to_evaluate_surrogate_model (self):
      return self.thisptr.hasToEvaluateSurrogateModel ()

   # checks if the solver has to evaluate the fine model representation
   def has_to_evaluate_fine_model (self):
      return self.thisptr.hasToEvaluateFineModel ()

   # action methods
   # check if action is needed
   def is_action_required (self, action):
      return self.thisptr.isActionRequired (action)

   # notify of action being fulfilled
   def fulfilled_action (self, action):
      self.thisptr.fulfilledAction (action)

   # mesh access
   # hasMesh
   def has_mesh(self, mesh_name):
      return self.thisptr.hasMesh (convert(mesh_name))

   # get mesh ID
   def get_mesh_id (self, mesh_name):
      return self.thisptr.getMeshID (convert(mesh_name))

   # get mesh IDs
   def get_mesh_ids (self):
      return self.thisptr.getMeshIDs ()

   # returns a handle to a created mesh
   def get_mesh_handle(self, mesh_name):
      raise Exception("The API method get_mesh_handle is not yet available for the Python bindings.")

   # creates a mesh vertex
   def set_mesh_vertex(self, mesh_id, position):
      cdef double* position_
      position_ = <double*> malloc(len(position) * sizeof(double))

      if position_ is NULL:
         raise MemoryError()

      for i in xrange(len(position)):
         position_[i] = position[i]

      vertex_id = self.thisptr.setMeshVertex(mesh_id, position_)

      free(position_)

      return vertex_id

   # returns the number of vertices of a mesh
   def get_mesh_vertex_size (self, mesh_id):
      return self.thisptr.getMeshVertexSize(mesh_id)
  
   # creates multiple mesh vertices
   def set_mesh_vertices (self, mesh_id, size, positions, ids):
      cdef int* ids_
      cdef double* positions_
      ids_ = <int*> malloc(len(ids) * sizeof(int))
      positions_ = <double*> malloc(len(positions) * sizeof(double))

      if ids_ is NULL or positions_ is NULL:
         raise MemoryError()
      
      for i in xrange(len(ids)):
         ids_[i] = ids[i]  # TODO: remove this and initialize ids_ empty. ids_ is used as return buffer.
      for i in xrange(len(positions)):
         positions_[i] = positions[i]

      self.thisptr.setMeshVertices (mesh_id, size, positions_, ids_)

      for i in xrange(len(ids)):
         ids[i] = ids_[i]
      for i in xrange(len(positions)):
         positions[i] = positions_[i]  # TODO: remove this. Writing positions_ back to positions is unnecessary. positions_ are const!

      free(ids_)
      free(positions_)

   # get vertex positions for multiple vertex ids from a given mesh
   def get_mesh_vertices(self, mesh_id, size, ids, positions):
      cdef int* ids_
      cdef double* positions_
      ids_ = <int*> malloc(len(ids) * sizeof(int))
      positions_ = <double*> malloc(len(positions) * sizeof(double))

      if ids_ is NULL or positions_ is NULL:
         raise MemoryError()
      
      for i in xrange(len(ids)):
         ids_[i] = ids[i]
      for i in xrange(len(positions)):
         positions_[i] = 0  # TODO: initialize empty: positions_ are used as return buffer.

      self.thisptr.getMeshVertices (mesh_id, size, ids_, positions_)

      for i in xrange(len(positions)):
         positions[i] = positions_[i]

      free(ids_)
      free(positions_)

   # gets mesh vertex IDs from positions
   def get_mesh_vertex_ids_from_positions (self, mesh_id, size, positions, ids):
      cdef int* ids_
      cdef double* positions_

      ids_ = <int*> malloc(len(ids) * sizeof(int))
      positions_ = <double*> malloc(len(positions) * sizeof(double))

      if ids_ is NULL or positions_ is NULL:
         raise MemoryError()
      
      for i in xrange(len(ids)):
         ids_[i] = ids[i]
      for i in xrange(len(positions)):
         positions_[i] = positions[i]

      self.thisptr.getMeshVertexIDsFromPositions (mesh_id, size, positions_, ids_)

      for i in xrange(len(ids)):
         ids[i] = ids_[i]
      for i in xrange(len(positions)):
         positions[i] = positions_[i]

      free(ids_)
      free(positions_)

   # sets mesh edge from vertex IDs, returns edge ID
   def set_mesh_edge (self, mesh_id, first_vertex_id, second_vertex_id):
      return self.thisptr.setMeshEdge (mesh_id, first_vertex_id, second_vertex_id)

   def set_mesh_triangle (self, mesh_id, first_edge_id, second_edge_id, third_edge_id):
      self.thisptr.setMeshTriangle (mesh_id, first_edge_id, second_edge_id, third_edge_id)

   def set_mesh_triangle_with_edges (self, mesh_id, first_vertex_id, second_vertex_id, third_vertex_id):
      self.thisptr.setMeshTriangleWithEdges (mesh_id, first_vertex_id, second_vertex_id, third_vertex_id)

   def set_mesh_quad (self, int mesh_id, first_edge_id, second_edge_id, third_edge_id, fourth_edge_id):
      self.thisptr.setMeshQuad (mesh_id, first_edge_id, second_edge_id, third_edge_id, fourth_edge_id)

   def set_mesh_quad_with_edges (self, mesh_id, first_vertex_id, second_vertex_id, third_vertex_id, fourth_vertex_id):
      self.thisptr.setMeshQuadWithEdges (mesh_id, first_vertex_id, second_vertex_id, third_vertex_id, fourth_vertex_id)

   # data access
   # hasData
   def has_data (self, data_name, mesh_id):
      return self.thisptr.hasData(convert(data_name), mesh_id)

   def get_data_id (self, data_name, mesh_id):
      return self.thisptr.getDataID (convert(data_name), mesh_id)
   
   def map_read_data_to (self, to_mesh_id):
      self.thisptr.mapReadDataTo (to_mesh_id)

   def map_write_data_from (self, from_mesh_id):
      self.thisptr.mapWriteDataFrom (from_mesh_id)

   def write_block_vector_data (self, data_id, size, value_indices, values):
      cdef int* value_indices_
      cdef double* values_
      value_indices_ = <int*> malloc(len(value_indices) * sizeof(int))
      values_ = <double*> malloc(len(values) * sizeof(double))

      if value_indices_ is NULL or values_ is NULL:
         raise MemoryError()
      
      for i in xrange(len(value_indices)):
         value_indices_[i] = value_indices[i]
      for i in xrange(len(values)):
         values_[i] = values[i]

      self.thisptr.writeBlockVectorData (data_id, size, value_indices_, values_)

      for i in xrange(len(value_indices)):
         value_indices[i] = value_indices_[i]
      for i in xrange(len(values)):
         values[i] = values_[i]

      free(value_indices_)
      free(values_)

   def write_vector_data (self, data_id, value_index, value):
      cdef double* value_
      value_ = <double*> malloc(len(value) * sizeof(double))

      if value_ is NULL:
         raise MemoryError()

      for i in xrange(len(value)):
         value_[i] = value[i]

      self.thisptr.writeVectorData (data_id, value_index, value_)

      for i in xrange(len(value)):
         value[i] = value_[i]

      free(value_)

   def write_block_scalar_data (self, data_id, size, value_indices, values):
      cdef int* value_indices_
      cdef double* values_
      value_indices_ = <int*> malloc(len(value_indices) * sizeof(int))
      values_ = <double*> malloc(len(values) * sizeof(double))

      if value_indices_ is NULL or values_ is NULL:
         raise MemoryError()
      
      for i in xrange(len(value_indices)):
         value_indices_[i] = value_indices[i]
      for i in xrange(len(values)):
         values_[i] = values[i]

      self.thisptr.writeBlockScalarData (data_id, size, value_indices_, values_)

      for i in xrange(len(value_indices)):
         value_indices[i] = value_indices_[i]
      for i in xrange(len(values)):
         values[i] = values_[i]

      free(value_indices_)
      free(values_)

   def write_scalar_data (self, data_id, value_index, value):
      self.thisptr.writeScalarData (data_id, value_index, value)

   def read_block_vector_data (self, data_id, size, value_indices, values):
      cdef int* value_indices_
      cdef double* values_
      value_indices_ = <int*> malloc(len(value_indices) * sizeof(int))
      values_ = <double*> malloc(len(values) * sizeof(double))

      if value_indices_ is NULL or values_ is NULL:
         raise MemoryError()
      
      for i in xrange(len(value_indices)):
         value_indices_[i] = value_indices[i]
      for i in xrange(len(values)):
         values_[i] = values[i]

      self.thisptr.readBlockVectorData (data_id, size, value_indices_, values_)

      for i in xrange(len(value_indices)):
         value_indices[i] = value_indices_[i]
      for i in xrange(len(values)):
         values[i] = values_[i]

      free(value_indices_)
      free(values_)

   def read_vector_data (self, data_id, value_index, value):
      cdef double* value_
      value_ = <double*> malloc(len(value) * sizeof(double))

      if value_ is NULL:
         raise MemoryError()

      for i in xrange(len(value)):
         value_[i] = value[i]

      self.thisptr.readVectorData (data_id, value_index, value_)

      for i in xrange(len(value)):
         value[i] = value_[i]

      free(value_)

   def read_block_scalar_data (self, data_id, size, value_indices, values):
      cdef int* value_indices_
      cdef double* values_
      value_indices_ = <int*> malloc(len(value_indices) * sizeof(int))
      values_ = <double*> malloc(len(values) * sizeof(double))

      if value_indices_ is NULL or values_ is NULL:
         raise MemoryError()
      
      for i in xrange(len(value_indices)):
         value_indices_[i] = value_indices[i]
      for i in xrange(len(values)):
         values_[i] = values[i]

      self.thisptr.readBlockScalarData (data_id, size, value_indices_, values_)

      for i in xrange(len(value_indices)):
         value_indices[i] = value_indices_[i]
      for i in xrange(len(values)):
         values[i] = values_[i]

      free(value_indices_)
      free(values_)

   def read_scalar_data (self, int data_id, int value_index, double& value):
      self.thisptr.readScalarData (data_id, value_index, value)

def action_write_initial_data ():
   return actionWriteInitialData()
   
def action_write_iteration_checkpoint ():
   return actionWriteIterationCheckpoint()

def action_read_iteration_checkpoint ():
   return actionReadIterationCheckpoint()

