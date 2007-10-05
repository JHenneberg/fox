 


module m_dom_parse

  use m_common_array_str, only: str_vs, vs_str_alloc
  use m_common_entities, only: entity_list, init_entity_list, destroy_entity_list, add_internal_entity
  use m_common_error, only: FoX_error
  use m_common_namespaces, only: namespaceDictionary, isDefaultNSInForce, getNumberOfPrefixes, &
    getPrefixByIndex
  use m_common_struct, only: xml_doc_state
  use FoX_common, only: dictionary_t, len
  use FoX_common, only: getQName, getValue, getURI, getLocalName, getSpecified
  use m_sax_parser, only: sax_parse
  use FoX_sax, only: xml_t
  use FoX_sax, only: open_xml_file, open_xml_string, close_xml_t

  use m_dom_dom, only: DOCUMENT_NODE, TEXT_NODE, CDATA_SECTION_NODE, getNodeType, &
    getDocType, Node, setDocType, getReadOnly, getData, setData, getNamespaceURI,&
    createProcessingInstruction, createAttributeNS, createComment, getEntities, &
    setSpecified, createElementNS, getNotations, createTextNode, createEntity, &
    getAttributes, setStringValue, createNamespaceNode, createNotation, setNamedItem, &
    createEmptyDocument, createDocumentType, getParentNode, setDocumentElement, &
    getNodeType, getImplementation, appendChild, getNotations, setAttributeNodeNS, &
    setvalue, setAttributeNodeNS, setGCstate, createCdataSection, setXds,  &
    createEntityReference, destroyAllNodesRecursively, setIllFormed, createElement, &
    createAttribute, getNamedItem, setReadonlyNode, setReadOnlyMap, &
    createEmptyEntityReference, setEntityReferenceValue, setAttributeNode, getLastChild, &
    getFoX_checks, getImplementation, getDocumentElement, setIsElementContentWhitespace, &
    DOMConfiguration, getParameter, destroy, setParameter, setDomConfig, namespaceFixup
  use m_dom_error, only: DOMException, inException, throw_exception, PARSE_ERR

  implicit none
  private

  public :: parsefile
  public :: parsestring

  type(xml_t), target, save :: fxml

  ! We need to maintain an entity list containing just internal entities 
  ! in order to be able to DOM-parse recursive entity declarations
  ! (Ideally wed just grab the SAX parsers copy, but that wont work in
  ! most Fortran compilers it seems, due to faulty optimization strategies)
  ! We only need to worry about internal entities; references to external
  ! entities will be caught and errors generated by the SAX parser

  type(entity_list), save :: elist
  type(Node), pointer, save  :: mainDoc => null()
  type(Node), pointer, save  :: current => null()

  type(DOMConfiguration), pointer :: domConfig
  
  logical :: cdata
  character, pointer :: error(:) => null()
  character, pointer :: inEntity(:) => null()

contains

  subroutine startElement_handler(URI, localname, name, attrs)
    character(len=*),   intent(in) :: URI
    character(len=*),   intent(in) :: localname
    character(len=*),   intent(in) :: name

    type(dictionary_t), intent(in) :: attrs
   
    type(Node), pointer :: el, attr, dummy
    integer              :: i

    if (getParameter(domConfig, "namespaces")) then
      el => createElementNS(mainDoc, URI, name)
    else
      el => createElement(mainDoc, name)
    endif

    do i = 1, len(attrs)
      if (getParameter(domConfig, "namespaces")) then
        attr => createAttributeNS(mainDoc, getURI(attrs, i), getQName(attrs, i))
      else
        attr => createAttribute(mainDoc, getQName(attrs, i))
      endif
      call setValue(attr, getValue(attrs, i))
      call setSpecified(attr, getSpecified(attrs, i))
      if (getParameter(domConfig, "namespaces")) then
        dummy => setAttributeNodeNS(el, attr)
      else
        dummy => setAttributeNode(el, attr)
      endif
      if (associated(inEntity)) call setReadOnlyNode(attr, .true., .true.)
    enddo

    if (associated(current, mainDoc)) then
      current => appendChild(current,el)
      call setDocumentElement(mainDoc, current)
    else
      current => appendChild(current,el)
    endif
    
    call namespaceFixup(current, .false.)

    if (associated(inEntity)) &
      call setReadOnlyMap(getAttributes(current), .true.)

    cdata = .false.

  end subroutine startElement_handler

  subroutine endElement_handler(URI, localName, name)
    character(len=*), intent(in)     :: URI
    character(len=*), intent(in)     :: localname
    character(len=*), intent(in)     :: name

    if (associated(inEntity)) call setReadOnlyNode(current, .true., .false.)

    current => getParentNode(current)
  end subroutine endElement_handler

  ! FIXME to pick up entity references within attribute values, we need
  ! separate just_the_element, start_attribute, attribute_text etc. calls.

  subroutine characters_handler(chunk)
    character(len=*), intent(in) :: chunk

    type(Node), pointer :: temp
    logical :: readonly

    temp => getLastChild(current)
    if (associated(temp)) then
      if (.not.cdata.and.getNodeType(temp)==TEXT_NODE) then
        readonly = getReadOnly(temp) ! Reset readonly status quickly
        call setReadOnlyNode(temp, .false., .false.)
        call setData(temp, getData(temp)//chunk)
        call setReadOnlyNode(temp, readonly, .false.)
        return
      endif
    endif
    if (cdata) then
      temp => createCdataSection(mainDoc, chunk)
      temp => appendChild(current, temp)
    else
      temp => createTextNode(mainDoc, chunk)
      temp => appendChild(current, temp)
    endif

    if (associated(inEntity)) call setReadOnlyNode(temp, .true., .false.)

  end subroutine characters_handler

  subroutine ignorableWhitespace_handler(chunk)
    character(len=*), intent(in) :: chunk

    type(Node), pointer :: temp
    logical :: readonly

    if (getParameter(domConfig, "element-content-whitespace")) then
      temp => getLastChild(current)
      if (associated(temp)) then
        if (getNodeType(temp)==TEXT_NODE) then
          readonly = getReadOnly(temp) ! Reset readonly status quickly
          call setReadOnlyNode(temp, .false., .false.)
          call setData(temp, getData(temp)//chunk)
          call setReadOnlyNode(temp, readonly, .false.)
          call setIsElementContentWhitespace(temp, .true.)
          return
        endif
      endif
      temp => createTextNode(mainDoc, chunk)
      temp => appendChild(current, temp)
      call setIsElementContentWhitespace(temp, .true.)
      if (associated(inEntity)) call setReadOnlyNode(temp, .true., .false.)
    endif

  end subroutine ignorableWhitespace_handler

  subroutine comment_handler(comment)
    character(len=*), intent(in) :: comment

    type(Node), pointer :: temp

    if (getParameter(domConfig, "comments")) then
      temp => appendChild(current, createComment(mainDoc, comment))
      if (associated(inEntity)) call setReadOnlyNode(temp, .true., .false.)
    endif

  end subroutine comment_handler

  subroutine processingInstruction_handler(target, data)
    character(len=*), intent(in) :: target
    character(len=*), intent(in) :: data

    type(Node), pointer :: temp

    temp => appendChild(current, &
      createProcessingInstruction(mainDoc, target, data))

    if (associated(inEntity)) call setReadOnlyNode(temp, .true., .false.)
  end subroutine processingInstruction_handler

  subroutine startDocument_handler
    mainDoc => createEmptyDocument()
    current => mainDoc
    call setGCstate(mainDoc, .false.)
    call setDomConfig(mainDoc, domConfig)
  end subroutine startDocument_handler

  subroutine endDocument_Handler
    call setGCstate(mainDoc, .true.)
  end subroutine endDocument_Handler

  subroutine startDTD_handler(name, publicId, systemId)
    character(len=*), intent(in) :: name
    character(len=*), intent(in) :: publicId
    character(len=*), intent(in) :: systemId

    type(Node), pointer :: np

    np => createDocumentType(getImplementation(mainDoc), name, publicId=publicId, systemId=systemId)
    np => appendChild(mainDoc, np)
    call setDocType(mainDoc, np)

  end subroutine startDTD_handler

  subroutine FoX_endDTD_handler(state)
    type(xml_doc_state), pointer :: state

    ! FIXME I think we ought to be able to not bother with this.
    ! if we do things right.
    call setXds(mainDoc, state)
    ! FIXME these could be just in the endDTD_handler
    if (associated(getDocType(mainDoc))) then
      call setReadonlyMap(getEntities(getDocType(mainDoc)), .true.)
      call setReadonlyMap(getNotations(getDocType(mainDoc)), .true.)
    endif

  end subroutine FoX_endDTD_handler

  subroutine notationDecl_handler(name, publicId, systemId)
    character(len=*), intent(in) :: name
    character(len=*), intent(in) ::  publicId
    character(len=*), intent(in) :: systemId
    
    type(Node), pointer :: np

    np => createNotation(mainDoc, name, publicId=publicId, systemId=systemId)
    np => setNamedItem(getNotations(getDocType(mainDoc)), np)
    ! The SAX parser will never give us duplicate entities,
    ! so there is no need to check

  end subroutine notationDecl_handler

  subroutine startCdata_handler()
    if (getParameter(domConfig, "cdata-sections")) cdata = .true.
  end subroutine startCdata_handler
  subroutine endCdata_handler()
    cdata = .false.
  end subroutine endCdata_handler

  subroutine internalEntityDecl_handler(name, value)
    character(len=*), intent(in) :: name
    character(len=*), intent(in) :: value
    
    type(Node), pointer :: oldcurrent
    type(xml_t) :: subsax
    type(entity_list), pointer :: el

    oldcurrent => getNamedItem(getEntities(getDocType(mainDoc)), name)
    ! If oldcurrent is associated, then this is a duplicate entity
    ! declaration & should be ignored
    if (.not.associated(oldcurrent)) then
      oldcurrent => current
      current => createEntity(mainDoc, name, "", "", "")
      call setStringValue(current, value)

      call open_xml_string(subsax, value)
      ! Run the parser over value
      ! We do this with all internal entities already declared; and
      ! namespace-handling switched *off*, since namespaces must be
      ! resolved lexically at the point where the entity is
      ! referenced ...; this will be done automatically for any
      ! entities referenced in the document, but we will need to do
      ! it manually when adding an ENTITY_REFERENCE NODE later on.
      ! FIXME false. actually we want to do partial namespace resolution
      ! at this stage, and at least pick up on xml: and xmlns: nodes
      call sax_parse(subsax%fx, subsax%fb,                           &
        startElement_handler=startElement_handler,                   &
        endElement_handler=endElement_handler,                       &
        characters_handler=characters_handler,                       &
        startCdata_handler=startCdata_handler,                       &
        endCdata_handler=endCdata_handler,                           &
        comment_handler=comment_handler,                             &
        processingInstruction_handler=processingInstruction_handler, &
        error_handler=entityErrorHandler,                            &
        startInCharData = .true., &
        namespaces=getParameter(domConfig, "namespaces"), &
        initial_entities = elist)
      ! FIXME namespaces take from domConfig
      call close_xml_t(subsax)
      call add_internal_entity(elist, name, value)

      current => setNamedItem(getEntities(getDocType(mainDoc)), current)
      current => oldcurrent
    endif

  end subroutine internalEntityDecl_handler

  subroutine normalErrorHandler(msg)
    character(len=*), intent(in) :: msg
    ! This is called if the main parsing routine fails
    error => vs_str_alloc(msg)
  end subroutine normalErrorHandler

  subroutine entityErrorHandler(msg)
    character(len=*), intent(in) :: msg

    !This gets called if parsing of an internal entity failed. If so,
    !then we need to destroy all nodes which were being generated as
    !children of this entity, then mark the entity as ill-formed - but
    !otherwise carry on parsing the document, and only throw an error
    !if a reference is made to it.

    call destroyAllNodesRecursively(current, except=.true.)
    call setIllFormed(current, .true.)
  end subroutine entityErrorHandler

  subroutine externalEntityDecl_handler(name, publicId, systemId)
    character(len=*), intent(in) :: name
    character(len=*), intent(in) :: publicId
    character(len=*), intent(in) :: systemId
    type(Node), pointer :: np

    np => createEntity(mainDoc, name, publicId=publicId, systemId=systemId, notationName="")

    np => getNamedItem(getEntities(getDocType(mainDoc)), name)
    if (.not.associated(np)) then
      np => createEntity(mainDoc, name, publicId=publicId, systemId=systemId, notationName="")
      np => setNamedItem(getEntities(getDocType(mainDoc)), np)
    endif    

  end subroutine externalEntityDecl_handler

  subroutine unparsedEntityDecl_handler(name, publicId, systemId, notationName)
    character(len=*), intent(in) :: name
    character(len=*), intent(in) :: publicId
    character(len=*), intent(in) :: systemId
    character(len=*), intent(in) :: notationName
    type(Node), pointer :: np

    np => getNamedItem(getEntities(getDocType(mainDoc)), name)
    if (.not.associated(np)) then
      np => createEntity(mainDoc, name, publicId=publicId, systemId=systemId, notationName=notationName)
      np => setNamedItem(getEntities(getDocType(mainDoc)), np)
    endif

  end subroutine unparsedEntityDecl_handler

  subroutine startEntity_handler(name)
    character(len=*), intent(in) :: name
    
    if (getParameter(domConfig, "entities")) then
      if (.not.associated(inEntity)) then
        inEntity => vs_str_alloc(name)
      endif
      current => appendChild(current, createEmptyEntityReference(mainDoc, name))
    endif
  end subroutine startEntity_handler

  subroutine endEntity_handler(name)
    character(len=*), intent(in) :: name
    
    if (getParameter(domConfig, "entities")) then
      call setEntityReferenceValue(current)
      call setReadOnlyNode(current, .true., .false.)
      if (str_vs(inEntity)==name) deallocate(inEntity)
      current => getParentNode(current)
    endif

  end subroutine endEntity_handler

  subroutine skippedEntity_handler(name)
    character(len=*), intent(in) :: name
    
    type(Node), pointer :: temp

    temp => appendChild(current, createEntityReference(mainDoc, name))
    if (associated(inEntity)) call setReadonlyNode(temp, .true., .false.)
  end subroutine skippedEntity_handler


  subroutine parseDOMOptions(configuration)
    character(len=*), intent(in), optional :: configuration

    allocate(domConfig)

    if (present(configuration)) then
      call setParameter(domConfig, "cdata-sections", &
        (index(configuration, "cdata-sections")==1).or.(index(configuration, " cdata-sections")>0))
      ! need to do double check to avoid finding split-cdata-sections
      call setParameter(domConfig, "entities", &
        index(configuration, "entities")>0)
      call setParameter(domConfig, "split-cdata-sections", &
        index(configuration, "split-cdata-sections")>0)
      call setParameter(domConfig, "validate", &
        index(configuration, "validate")>0)
    endif

  end subroutine parseDOMOptions

  subroutine runParser(fxml, ex)
    type(DOMException), intent(out), optional :: ex
    type(xml_t), intent(inout) :: fxml

! We use internal sax_parse rather than public interface in order
! to use internal callbacks to get extra info.
    call init_entity_list(elist)
    call sax_parse(fx=fxml%fx, fb=fxml%fb,&
      characters_handler=characters_handler,            &
      endDocument_handler=endDocument_handler,           &
      endElement_handler=endElement_handler,            &
      !endPrefixMapping_handler,      &
      ignorableWhitespace_handler=ignorableWhitespace_handler,   &
      processingInstruction_handler=processingInstruction_handler, &
      ! setDocumentLocator
      skippedEntity_handler=skippedEntity_handler,         &
      startDocument_handler=startDocument_handler,         & 
      startElement_handler=startElement_handler,          &
      !startPrefixMapping_handler,    &
      notationDecl_handler=notationDecl_handler,          &
      unparsedEntityDecl_handler=unparsedEntityDecl_handler, &
      error_handler=normalErrorHandler,                 &
      !fatalError_handler,            &
      !warning_handler,               &
      !attributeDecl_handler,         &
      !elementDecl_handler,           &
      externalEntityDecl_handler=externalEntityDecl_handler, &
      internalEntityDecl_handler=internalEntityDecl_handler,    &
      comment_handler=comment_handler,              &
      endCdata_handler=endCdata_handler,             &
      !endDTD_handler=endDTD_handler,                &
      endEntity_handler=endEntity_handler,             &
      startCdata_handler=startCdata_handler,    &
      startDTD_handler=startDTD_handler,          &
      startEntity_handler=startEntity_handler, &
      FoX_endDTD_handler=FoX_endDTD_handler, &
      namespaces = getParameter(domConfig, "namespaces"),     &
      namespace_prefixes = .true., &
      validate = getParameter(domConfig, "validate"), & ! FIXME what about validate-if-present ...
      xmlns_uris = .true.)

    call close_xml_t(fxml)
    call destroy_entity_list(elist)

    if (associated(error)) then
      ! FIXME pass the value of the error through
      ! when we let exceptions do that
      call destroy(mainDoc)
      if (getFoX_checks().or.PARSE_ERR<200) then
  call throw_exception(PARSE_ERR, "runParser", ex)
  if (present(ex)) then
    if (inException(ex)) then
       return
    endif
  endif
endif

    endif

  end subroutine runParser


  function parsefile(filename, configuration, ex) 
    type(DOMException), intent(out), optional :: ex
    character(len=*), intent(in) :: filename
    character(len=*), intent(in), optional :: configuration
    type(Node), pointer :: parsefile
    integer :: iostat

    call parseDOMOptions(configuration)

    call open_xml_file(fxml, filename, iostat)
    if (iostat /= 0) then
      call FoX_error("Cannot open file")
    endif

    call runParser(fxml, ex)

    parsefile => mainDoc
    mainDoc => null()

  end function parsefile


  function parsestring(string, configuration, ex) 
    type(DOMException), intent(out), optional :: ex
    character(len=*), intent(in) :: string
    character(len=*), intent(in), optional :: configuration
    type(Node), pointer :: parsestring

    call parseDOMOptions(configuration)

    call open_xml_string(fxml, string)

    call runParser(fxml, ex)

    parsestring => mainDoc
    mainDoc => null()
    
  end function parsestring

end module m_dom_parse
