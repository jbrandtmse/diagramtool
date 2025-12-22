```mermaid
sequenceDiagram
%% Session 6641
participant MA.CEN.IHE.XCA.RespondingGateway.Services
participant MA.CEN.IHE.XDSb.Query.Process
participant MA.CEN.Registry.Document.Manager
participant MA.CEN.Registry.Document.Operations
MA.CEN.IHE.XCA.RespondingGateway.Services ->> MA.CEN.IHE.XDSb.Query.Process : HS.Message.XMLMessage
loop 14 times MA.Message.AddUpdateDocumentRequest
  MA.CEN.IHE.XDSb.Query.Process ->> MA.CEN.Registry.Document.Manager : MA.Message.AddUpdateDocumentRequest
  MA.CEN.Registry.Document.Manager ->> MA.CEN.Registry.Document.Operations : MA.Message.AddUpdateDocumentRequest
  MA.CEN.Registry.Document.Operations ->> MA.CEN.Registry.Document.Manager : HS.Message.XMLMessage
  MA.CEN.Registry.Document.Manager ->> MA.CEN.IHE.XDSb.Query.Process : HS.Message.XMLMessage
end
MA.CEN.IHE.XDSb.Query.Process ->> MA.CEN.IHE.XCA.RespondingGateway.Services : HS.Message.XMLMessage
```
